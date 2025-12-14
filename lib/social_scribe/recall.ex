defmodule SocialScribe.Recall do
  @moduledoc "The real implementation for the Recall.ai API client."
  @behaviour SocialScribe.RecallApi
  require Logger

  defp client do
    api_key = Application.fetch_env!(:social_scribe, :recall_api_key)
    recall_region = Application.fetch_env!(:social_scribe, :recall_region)

    Tesla.client([
      {Tesla.Middleware.BaseUrl, "https://#{recall_region}.recall.ai/api/v1"},
      {Tesla.Middleware.JSON, engine_opts: [keys: :atoms]},
      {Tesla.Middleware.Headers,
       [
         {"Authorization", "Token #{api_key}"},
         {"Content-Type", "application/json"},
         {"Accept", "application/json"}
       ]}
    ])
  end

  @impl SocialScribe.RecallApi
  def create_bot(meeting_url, join_at) do
    body = %{
      meeting_url: meeting_url,
      join_at: Timex.format!(join_at, "{ISO:Extended}")
    }

    Tesla.post(client(), "/bot", body)
  end

  @impl SocialScribe.RecallApi
  def update_bot(recall_bot_id, meeting_url, join_at) do
    body = %{
      meeting_url: meeting_url,
      join_at: Timex.format!(join_at, "{ISO:Extended}")
    }

    Tesla.patch(client(), "/bot/#{recall_bot_id}", body)
  end

  @impl SocialScribe.RecallApi
  def delete_bot(recall_bot_id) do
    Tesla.delete(client(), "/bot/#{recall_bot_id}")
  end

  @impl SocialScribe.RecallApi
  def get_bot(recall_bot_id) do
    Tesla.get(client(), "/bot/#{recall_bot_id}")
  end

  @impl SocialScribe.RecallApi
  def get_bot_transcript(recall_bot_id) do
    Tesla.get(client(), "/bot/#{recall_bot_id}/transcript/")
  end

  @impl SocialScribe.RecallApi
  def get_transcript(transcript_id) do
    url = "/transcript/#{transcript_id}/"
    region = Application.get_env(:social_scribe, :recall_region, "unknown")
    Logger.info("Fetching transcript. Region: #{region}, Path: #{url}")
    Tesla.get(client(), url)
  end

  @impl SocialScribe.RecallApi
  def request_transcript_creation(recording_id) do
    url = "/recording/#{recording_id}/create_transcript/"
    body = %{
      provider: %{
        recallai_async: %{}
      }
    }

    Logger.info("Requesting transcript creation for recording #{recording_id}")
    case Tesla.post(client(), url, body) do
      {:ok, response} ->
        Logger.info("Transcript creation response: #{inspect(response)}")
        {:ok, response}
      error ->
        Logger.error("Transcript creation failed: #{inspect(error)}")
        error
    end
  end
end
