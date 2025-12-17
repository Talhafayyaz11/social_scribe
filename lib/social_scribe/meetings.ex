defmodule SocialScribe.Meetings do
  @moduledoc """
  The Meetings context.
  """

  import Ecto.Query, warn: false
  alias SocialScribe.Repo

  alias SocialScribe.Meetings.Meeting
  alias SocialScribe.Meetings.MeetingTranscript
  alias SocialScribe.Meetings.MeetingParticipant
  alias SocialScribe.Bots.RecallBot

  require Logger

  @doc """
  Returns the list of meetings.

  ## Examples

      iex> list_meetings()
      [%Meeting{}, ...]

  """
  def list_meetings do
    Repo.all(Meeting)
  end

  @doc """
  Gets a single meeting.

  Raises `Ecto.NoResultsError` if the Meeting does not exist.

  ## Examples

      iex> get_meeting!(123)
      %Meeting{}

      iex> get_meeting!(456)
      ** (Ecto.NoResultsError)

  """
  def get_meeting!(id), do: Repo.get!(Meeting, id)

  @doc """
  Gets a meeting by recall bot id.

  ## Examples

      iex> get_meeting_by_recall_bot_id(123)
      %Meeting{}

  """
  def get_meeting_by_recall_bot_id(recall_bot_id) do
    Repo.get_by(Meeting, recall_bot_id: recall_bot_id)
  end

  @doc """
  Creates a meeting.

  ## Examples

      iex> create_meeting(%{field: value})
      {:ok, %Meeting{}}

      iex> create_meeting(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_meeting(attrs \\ %{}) do
    %Meeting{}
    |> Meeting.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a meeting.

  ## Examples

      iex> update_meeting(meeting, %{field: new_value})
      {:ok, %Meeting{}}

      iex> update_meeting(meeting, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_meeting(%Meeting{} = meeting, attrs) do
    meeting
    |> Meeting.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a meeting.

  ## Examples

      iex> delete_meeting(meeting)
      {:ok, %Meeting{}}

      iex> delete_meeting(meeting)
      {:error, %Ecto.Changeset{}}

  """
  def delete_meeting(%Meeting{} = meeting) do
    Repo.delete(meeting)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking meeting changes.

  ## Examples

      iex> change_meeting(meeting)
      %Ecto.Changeset{data: %Meeting{}}

  """
  def change_meeting(%Meeting{} = meeting, attrs \\ %{}) do
    Meeting.changeset(meeting, attrs)
  end

  @doc """
  Lists all processed meetings for a user.
  """
  def list_user_meetings(user) do
    from(m in Meeting,
      join: ce in assoc(m, :calendar_event),
      where: ce.user_id == ^user.id,
      order_by: [desc: m.recorded_at],
      preload: [:meeting_transcript, :meeting_participants, :recall_bot]
    )
    |> Repo.all()
  end

  @doc """
  Gets a meeting with its details preloaded.

  ## Examples

      iex> get_meeting_with_details(123)
      %Meeting{}
  """
  def get_meeting_with_details(meeting_id) do
    Meeting
    |> Repo.get(meeting_id)
    |> Repo.preload([:calendar_event, :recall_bot, :meeting_transcript, :meeting_participants])
  end

  alias SocialScribe.Meetings.MeetingTranscript

  @doc """
  Returns the list of meeting_transcripts.

  ## Examples

      iex> list_meeting_transcripts()
      [%MeetingTranscript{}, ...]

  """
  def list_meeting_transcripts do
    Repo.all(MeetingTranscript)
  end

  @doc """
  Gets a single meeting_transcript.

  Raises `Ecto.NoResultsError` if the Meeting transcript does not exist.

  ## Examples

      iex> get_meeting_transcript!(123)
      %MeetingTranscript{}

      iex> get_meeting_transcript!(456)
      ** (Ecto.NoResultsError)

  """
  def get_meeting_transcript!(id), do: Repo.get!(MeetingTranscript, id)

  @doc """
  Creates a meeting_transcript.

  ## Examples

      iex> create_meeting_transcript(%{field: value})
      {:ok, %MeetingTranscript{}}

      iex> create_meeting_transcript(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_meeting_transcript(attrs \\ %{}) do
    %MeetingTranscript{}
    |> MeetingTranscript.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a meeting_transcript.

  ## Examples

      iex> update_meeting_transcript(meeting_transcript, %{field: new_value})
      {:ok, %MeetingTranscript{}}

      iex> update_meeting_transcript(meeting_transcript, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_meeting_transcript(%MeetingTranscript{} = meeting_transcript, attrs) do
    meeting_transcript
    |> MeetingTranscript.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a meeting_transcript.

  ## Examples

      iex> delete_meeting_transcript(meeting_transcript)
      {:ok, %MeetingTranscript{}}

      iex> delete_meeting_transcript(meeting_transcript)
      {:error, %Ecto.Changeset{}}

  """
  def delete_meeting_transcript(%MeetingTranscript{} = meeting_transcript) do
    Repo.delete(meeting_transcript)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking meeting_transcript changes.

  ## Examples

      iex> change_meeting_transcript(meeting_transcript)
      %Ecto.Changeset{data: %MeetingTranscript{}}

  """
  def change_meeting_transcript(%MeetingTranscript{} = meeting_transcript, attrs \\ %{}) do
    MeetingTranscript.changeset(meeting_transcript, attrs)
  end

  alias SocialScribe.Meetings.MeetingParticipant

  @doc """
  Returns the list of meeting_participants.

  ## Examples

      iex> list_meeting_participants()
      [%MeetingParticipant{}, ...]

  """
  def list_meeting_participants do
    Repo.all(MeetingParticipant)
  end

  @doc """
  Gets a single meeting_participant.

  Raises `Ecto.NoResultsError` if the Meeting participant does not exist.

  ## Examples

      iex> get_meeting_participant!(123)
      %MeetingParticipant{}

      iex> get_meeting_participant!(456)
      ** (Ecto.NoResultsError)

  """
  def get_meeting_participant!(id), do: Repo.get!(MeetingParticipant, id)

  @doc """
  Creates a meeting_participant.

  ## Examples

      iex> create_meeting_participant(%{field: value})
      {:ok, %MeetingParticipant{}}

      iex> create_meeting_participant(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_meeting_participant(attrs \\ %{}) do
    %MeetingParticipant{}
    |> MeetingParticipant.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a meeting_participant.

  ## Examples

      iex> update_meeting_participant(meeting_participant, %{field: new_value})
      {:ok, %MeetingParticipant{}}

      iex> update_meeting_participant(meeting_participant, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_meeting_participant(%MeetingParticipant{} = meeting_participant, attrs) do
    meeting_participant
    |> MeetingParticipant.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a meeting_participant.

  ## Examples

      iex> delete_meeting_participant(meeting_participant)
      {:ok, %MeetingParticipant{}}

      iex> delete_meeting_participant(meeting_participant)
      {:error, %Ecto.Changeset{}}

  """
  def delete_meeting_participant(%MeetingParticipant{} = meeting_participant) do
    Repo.delete(meeting_participant)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking meeting_participant changes.

  ## Examples

      iex> change_meeting_participant(meeting_participant)
      %Ecto.Changeset{data: %MeetingParticipant{}}

  """
  def change_meeting_participant(%MeetingParticipant{} = meeting_participant, attrs \\ %{}) do
    MeetingParticipant.changeset(meeting_participant, attrs)
  end

  @doc """
  Creates a complete meeting record from Recall.ai bot info and transcript data.
  This should be called when a bot's status is "done".
  """
  def create_meeting_from_recall_data(%RecallBot{} = recall_bot, bot_api_info, transcript_data) do
    calendar_event = Repo.preload(recall_bot, :calendar_event).calendar_event

    # Fetch actual content if transcript_data contains a download URL
    transcript_data = maybe_fetch_transcript_content(transcript_data)

    Repo.transaction(fn ->
      try do
        Logger.info("Starting meeting creation transaction")
        meeting_attrs = parse_meeting_attrs(calendar_event, recall_bot, bot_api_info)
        Logger.info("Meeting attrs: #{inspect(meeting_attrs)}")

        meeting =
          case create_meeting(meeting_attrs) do
            {:ok, m} ->
              Logger.info("Meeting created: #{m.id}")
              m

            {:error, cs} ->
              Logger.error("Meeting creation failed: #{inspect(cs)}")
              Repo.rollback(cs)
          end

        transcript_attrs = parse_transcript_attrs(meeting, transcript_data)

        case create_meeting_transcript(transcript_attrs) do
          {:ok, _} ->
            Logger.info("Transcript created")

          {:error, reason} ->
            Logger.error("Failed to create transcript: #{inspect(reason)}")
            # Don't rollback, just continue
        end

        # Fetch participants from the download URL if available
        participants = fetch_participants_from_bot_info(bot_api_info)
        Logger.info("Found #{length(participants)} participants to process")

        Enum.each(participants, fn participant_data ->
          try do
            Logger.debug("Raw participant data: #{inspect(participant_data)}")
            participant_attrs = parse_participant_attrs(meeting, participant_data)
            Logger.debug("Parsed participant attrs: #{inspect(participant_attrs)}")

            case create_meeting_participant(participant_attrs) do
              {:ok, participant} ->
                Logger.info(
                  "Created participant: #{participant.name} (ID: #{participant.recall_participant_id})"
                )

                :ok

              {:error, reason} ->
                Logger.error("Failed to create participant: #{inspect(reason)}")
            end
          rescue
            e -> Logger.error("Participant parsing failed: #{inspect(e)}")
          end
        end)

        Logger.info("Participants processed")

        Repo.preload(meeting, [:meeting_transcript, :meeting_participants])
      rescue
        e ->
          Logger.error("CRITICAL ERROR in meeting creation: #{inspect(e)}")
          Logger.error(Exception.format(:error, e, __STACKTRACE__))
          Repo.rollback(e)
      end
    end)
  end

  defp maybe_fetch_transcript_content(transcript_data) do
    # Guard against list input (legacy format)
    download_url =
      if is_map(transcript_data) do
        fetch_value(transcript_data, :data) |> fetch_value(:download_url)
      else
        nil
      end

    if download_url do
      Logger.info("Fetching transcript content from download URL: #{download_url}")
      # Use basic Tesla or httpc. Since Tesla is configured for Recall (with base URL),
      # we should use a fresh client for this absolute URL.
      # Or just use the URL directly if Tesla supports absolute URLs overriding base. It usually does not with BaseUrl middleware.
      # Safest is to use :httpc or a bare Tesla client.
      case Tesla.get(download_url) do
        {:ok, %{status: 200, body: body}} ->
          Logger.info("Successfully downloaded transcript content.")

          decoded =
            case body do
              body when is_binary(body) ->
                case Jason.decode(body) do
                  {:ok, d} -> d
                  _ -> body
                end

              body ->
                body
            end

          decoded

        {:ok, response} ->
          # Maybe Tesla.Middleware.JSON was applied globally?
          # If body is map, return it.
          if is_map(response.body), do: response.body, else: response.body

        error ->
          Logger.error("Failed to download transcript content: #{inspect(error)}")
          transcript_data
      end
    else
      transcript_data
    end
  end

  # --- Private Parser Functions ---

  defp parse_meeting_attrs(calendar_event, recall_bot, bot_api_info) do
    recordings = fetch_value(bot_api_info, :recordings) || []
    recording_info = List.first(recordings) || %{}

    completed_at =
      case DateTime.from_iso8601(fetch_value(recording_info, :completed_at) || "") do
        {:ok, parsed_completed_at, _} -> parsed_completed_at
        _ -> nil
      end

    recorded_at =
      case DateTime.from_iso8601(fetch_value(recording_info, :started_at) || "") do
        {:ok, parsed_recorded_at, _} -> parsed_recorded_at
        _ -> calendar_event.start_time
      end

    duration_seconds =
      if recorded_at && completed_at do
        DateTime.diff(completed_at, recorded_at, :second)
      else
        nil
      end

    meeting_metadata = fetch_value(bot_api_info, :meeting_metadata) || %{}

    title =
      calendar_event.summary || fetch_value(meeting_metadata, :title) ||
        "Recorded Meeting"

    %{
      title: title,
      recorded_at: recorded_at,
      duration_seconds: duration_seconds,
      calendar_event_id: calendar_event.id,
      recall_bot_id: recall_bot.id
    }
  end

  defp parse_transcript_attrs(meeting, transcript_data) do
    first_segment = if is_list(transcript_data), do: List.first(transcript_data), else: nil

    language =
      if is_map(first_segment) do
        fetch_value(first_segment, :language) || "unknown"
      else
        "unknown"
      end

    %{
      meeting_id: meeting.id,
      content: %{data: transcript_data},
      language: language
    }
  end

  defp parse_participant_attrs(meeting, participant_data) do
    %{
      meeting_id: meeting.id,
      recall_participant_id: to_string(fetch_value(participant_data, :id)),
      name: fetch_value(participant_data, :name) || "Unknown Participant",
      is_host: fetch_value(participant_data, :is_host) || false
    }
  end

  defp fetch_participants_from_bot_info(bot_api_info) do
    Logger.info("PARTICIPANTS FETCH: Starting to extract participants from bot_api_info")

    # Try to get participants from the download URL in recordings
    recordings = fetch_value(bot_api_info, :recordings) || []
    Logger.info("PARTICIPANTS FETCH: Found #{length(recordings)} recordings")

    first_recording = List.first(recordings)

    if first_recording do
      Logger.debug("PARTICIPANTS FETCH: First recording exists")
      media_shortcuts = fetch_value(first_recording, :media_shortcuts)

      if media_shortcuts do
        Logger.debug("PARTICIPANTS FETCH: media_shortcuts exists")
        participant_events = fetch_value(media_shortcuts, :participant_events)

        if participant_events do
          Logger.debug("PARTICIPANTS FETCH: participant_events exists")
          data = fetch_value(participant_events, :data)

          if data do
            Logger.debug("PARTICIPANTS FETCH: data field exists")
            participants_url = fetch_value(data, :participants_download_url)

            Logger.info("PARTICIPANTS FETCH: participants_url = #{inspect(participants_url)}")

            if participants_url do
              Logger.info("Fetching participants from download URL: #{participants_url}")

              case Tesla.get(participants_url) do
                {:ok, %{status: 200, body: body}} ->
                  Logger.info("Successfully downloaded participants data")

                  Logger.debug(
                    "PARTICIPANTS FETCH: Raw body type: #{if is_binary(body), do: "binary", else: if(is_map(body), do: "map", else: "other")}"
                  )

                  # Parse the response
                  participants_data =
                    case body do
                      body when is_binary(body) ->
                        Logger.debug("PARTICIPANTS FETCH: Body is binary, decoding JSON")

                        case Jason.decode(body, keys: :atoms) do
                          {:ok, decoded} ->
                            Logger.info("PARTICIPANTS FETCH: Decoded JSON successfully")
                            decoded

                          error ->
                            Logger.error(
                              "PARTICIPANTS FETCH: JSON decode failed: #{inspect(error)}"
                            )

                            body
                        end

                      body when is_map(body) ->
                        Logger.debug("PARTICIPANTS FETCH: Body is already a map")
                        body

                      _ ->
                        Logger.warning("PARTICIPANTS FETCH: Body is neither binary nor map")
                        []
                    end

                  # Extract participants array
                  result =
                    cond do
                      is_list(participants_data) ->
                        Logger.info(
                          "PARTICIPANTS FETCH: Data is already a list with #{length(participants_data)} items"
                        )

                        participants_data

                      is_map(participants_data) ->
                        extracted = fetch_value(participants_data, :participants) || []

                        Logger.info(
                          "PARTICIPANTS FETCH: Extracted #{length(extracted)} participants from map"
                        )

                        extracted

                      true ->
                        Logger.warning("PARTICIPANTS FETCH: Data is neither list nor map")
                        []
                    end

                  Logger.info("PARTICIPANTS FETCH: Returning #{length(result)} participants")
                  result

                {:ok, response} ->
                  Logger.warning(
                    "Got non-200 response when fetching participants: #{inspect(response.status)}"
                  )

                  []

                error ->
                  Logger.error("Failed to download participants: #{inspect(error)}")
                  []
              end
            else
              Logger.info("No participants download URL available (may still be processing)")
              []
            end
          else
            Logger.debug("No data field in participant_events")
            []
          end
        else
          Logger.debug("No participant_events in media_shortcuts")
          []
        end
      else
        Logger.debug("No media_shortcuts in recording")
        []
      end
    else
      Logger.debug("No recordings available")
      []
    end
  end

  defp fetch_value(map, key) when is_map(map) and is_atom(key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp fetch_value(map, key) when is_map(map) and is_binary(key) do
    Map.get(map, key) || Map.get(map, String.to_existing_atom(key))
  rescue
    _ -> nil
  end

  defp fetch_value(_map, _key), do: nil

  @doc """
  Generates a prompt for a meeting.
  """
  def generate_prompt_for_meeting(%Meeting{} = meeting) do
    participants_string =
      case participants_to_string(meeting.meeting_participants) do
        {:error, :no_participants} ->
          "Unknown Participants"

        {:ok, participants_string} ->
          participants_string
      end

    case transcript_to_string(meeting.meeting_transcript) do
      {:error, :no_transcript} ->
        {:error, :no_transcript}

      {:ok, transcript_string} ->
        {:ok,
         generate_prompt(
           meeting.title,
           meeting.recorded_at,
           meeting.duration_seconds,
           participants_string,
           transcript_string
         )}
    end
  end

  defp generate_prompt(title, date, duration, participants, transcript) do
    """
    ## Meeting Info:
    title: #{title}
    date: #{date}
    duration: #{duration} seconds

    ### Participants:
    #{participants}

    ### Transcript:
    #{transcript}
    """
  end

  defp participants_to_string(participants) do
    if Enum.empty?(participants) do
      {:error, :no_participants}
    else
      participants_string =
        participants
        |> Enum.map(fn participant ->
          "#{participant.name} (#{if participant.is_host, do: "Host", else: "Participant"})"
        end)
        |> Enum.join("\n")

      {:ok, participants_string}
    end
  end

  def get_transcript_with_timestamps(%Meeting{} = meeting) do
    case transcript_to_string(meeting.meeting_transcript, true) do
      {:ok, transcript_string} -> {:ok, transcript_string}
      _ -> {:error, :no_transcript}
    end
  end

  defp transcript_to_string(
         %MeetingTranscript{content: %{"data" => transcript_data}},
         with_timestamps \\ false
       )
       when not is_nil(transcript_data) do
    {:ok, format_transcript_for_prompt(transcript_data, with_timestamps)}
  end

  defp transcript_to_string(_, _), do: {:error, :no_transcript}

  defp format_transcript_for_prompt(transcript_segments, with_timestamps \\ false)
       when is_list(transcript_segments) do
    Enum.map_join(transcript_segments, "\n", fn segment ->
      speaker =
        segment["speaker"] || get_in(segment, ["participant", "name"]) || "Unknown Speaker"

      words = Map.get(segment, "words", [])

      if Enum.empty?(words) do
        # Fallback if no words (legacy or summarized)
        text = Map.get(segment, "text", "")

        start_time =
          extract_seconds(Map.get(segment, "start_timestamp") || Map.get(segment, "start_time"))

        format_line(speaker, text, start_time, with_timestamps)
      else
        # Chunk words by sentence to provide detailed timestamps
        words
        |> chunk_words_by_sentence()
        |> Enum.map_join("\n", fn {sentence_words, start_timestamp} ->
          text = Enum.map_join(sentence_words, " ", &Map.get(&1, "text", ""))
          format_line(speaker, text, start_timestamp, with_timestamps)
        end)
      end
    end)
  end

  defp chunk_words_by_sentence(words) do
    Enum.reduce(words, {[], []}, fn word, {current_sentence, sentences} ->
      text = Map.get(word, "text", "")
      is_end_of_sentence = String.match?(text, ~r/[.?!]$/)

      # If this is the start of a new sentence, capture timestamp
      new_sentence = current_sentence ++ [word]

      if is_end_of_sentence do
        # Finish current sentence
        sentence_start_time = get_start_time(List.first(new_sentence))
        {[], sentences ++ [{new_sentence, sentence_start_time}]}
      else
        # Continue sentence
        {new_sentence, sentences}
      end
    end)
    |> case do
      {[], sentences} ->
        sentences

      {remaining, sentences} ->
        # Flush remaining words
        sentence_start_time = get_start_time(List.first(remaining))
        sentences ++ [{remaining, sentence_start_time}]
    end
  end

  defp get_start_time(word) do
    if word do
      extract_seconds(Map.get(word, "start_timestamp") || Map.get(word, "start_time"))
    else
      0
    end
  end

  defp format_line(speaker, text, start_time, true) do
    formatted_time = format_timestamp(start_time)
    "[#{formatted_time}] #{speaker}: #{text}"
  end

  defp format_line(speaker, text, _start_time, false) do
    "#{speaker}: #{text}"
  end

  defp extract_seconds(timestamp) when is_number(timestamp), do: timestamp

  defp extract_seconds(timestamp) when is_map(timestamp) do
    Map.get(timestamp, "relative") || Map.get(timestamp, :relative) || 0
  end

  defp extract_seconds(_), do: 0

  defp format_timestamp(seconds) when is_number(seconds) do
    minutes = floor(seconds / 60)
    remaining_seconds = floor(seconds - minutes * 60)
    formatted_minutes = String.pad_leading("#{minutes}", 2, "0")
    formatted_seconds = String.pad_leading("#{remaining_seconds}", 2, "0")
    "#{formatted_minutes}:#{formatted_seconds}"
  end

  defp format_timestamp(_), do: "00:00"
end
