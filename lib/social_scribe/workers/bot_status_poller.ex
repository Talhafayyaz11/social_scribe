defmodule SocialScribe.Workers.BotStatusPoller do
  use Oban.Worker, queue: :polling, max_attempts: 3

  alias SocialScribe.Bots
  alias SocialScribe.RecallApi
  alias SocialScribe.Meetings

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    bots_to_poll = Bots.list_pending_bots()

    if Enum.any?(bots_to_poll) do
      Logger.info("Polling #{Enum.count(bots_to_poll)} pending Recall.ai bots...")
    end

    for bot_record <- bots_to_poll do
      poll_and_process_bot(bot_record)
    end

    :ok
  end

  defp poll_and_process_bot(bot_record) do
    case RecallApi.get_bot(bot_record.recall_bot_id) do
      {:ok, %Tesla.Env{body: bot_api_info}} ->
        Logger.info("Bot API Info: #{inspect(bot_api_info)}")

        status_changes = Map.get(bot_api_info, :status_changes) || []

        new_status =
          if Enum.empty?(status_changes) do
             # If no status changes, assume it's still in the initial state or use existing
             bot_record.status
          else
             status_changes
             |> List.last()
             |> Map.get(:code)
          end

        {:ok, updated_bot_record} = Bots.update_recall_bot(bot_record, %{status: new_status})

        if new_status == "done" &&
             is_nil(Meetings.get_meeting_by_recall_bot_id(updated_bot_record.id)) do
          process_completed_bot(updated_bot_record, bot_api_info)
        else
          if new_status != bot_record.status do
            Logger.info("Bot #{bot_record.recall_bot_id} status updated to: #{new_status}")
          end
        end

      {:error, reason} ->
        Logger.error(
          "Failed to poll bot status for #{bot_record.recall_bot_id}: #{inspect(reason)}"
        )

        Bots.update_recall_bot(bot_record, %{status: "polling_error"})
    end
  end

  defp process_completed_bot(bot_record, bot_api_info) do
    Logger.info("Bot #{bot_record.recall_bot_id} is done. Fetching transcript...")

    # Try to find transcript ID in media_shortcuts
    recordings = Map.get(bot_api_info, :recordings, [])

    transcript_id =
      recordings
      |> Enum.find_value(fn recording ->
        get_in(recording, [:media_shortcuts, :transcript, :id])
      end)

    if transcript_id do
      Logger.info("Found transcript ID #{transcript_id}, fetching...")
      case RecallApi.get_transcript(transcript_id) do
        {:ok, %Tesla.Env{body: transcript_data}} ->
          Logger.info("Successfully fetched transcript for bot #{bot_record.recall_bot_id}")
          create_meeting_record(bot_record, bot_api_info, transcript_data)

        {:error, reason} ->
          Logger.error(
            "Failed to fetch transcript for bot #{bot_record.recall_bot_id}: #{inspect(reason)}"
          )
      end
    else
      # No transcript ID found, check if we can trigger creation
      recording_id =
        recordings
        |> List.first()
        |> Map.get(:id)

      if recording_id do
        Logger.info("No transcript ID found. Triggering/Checking creation for recording #{recording_id}...")

        # Trigger creation (fire and forget, or handle duplicate)
        RecallApi.request_transcript_creation(recording_id)

        # IMPORTANT: Set status to "processing_transcript" so the poller picks it up again
        Bots.update_recall_bot(bot_record, %{status: "processing_transcript"})
        Logger.info("Bot set to 'processing_transcript' to wait for completion.")
      else
        Logger.warning("No recording ID found for bot #{bot_record.recall_bot_id}. Creating meeting without transcript.")
        # Fallback to creating meeting with nil transcript (empty list)
        create_meeting_record(bot_record, bot_api_info, [])
      end
    end
  end

  defp create_meeting_record(bot_record, bot_api_info, transcript_data) do
    case Meetings.create_meeting_from_recall_data(bot_record, bot_api_info, transcript_data) do
      {:ok, meeting} ->
        Logger.info(
          "Successfully created meeting record #{meeting.id} from bot #{bot_record.recall_bot_id}"
        )

        SocialScribe.Workers.AIContentGenerationWorker.new(%{meeting_id: meeting.id})
        |> Oban.insert()

        Logger.info("Enqueued AI content generation for meeting #{meeting.id}")

      {:error, reason} ->
        Logger.error(
          "Failed to create meeting record from bot #{bot_record.recall_bot_id}: #{inspect(reason)}"
        )
    end
  end
end
