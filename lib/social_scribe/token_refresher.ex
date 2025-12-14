defmodule SocialScribe.TokenRefresher do
  @moduledoc """
  Refreshes Google tokens.
  """

  @google_token_url "https://oauth2.googleapis.com/token"

  @behaviour SocialScribe.TokenRefresherApi

  def client do
    middlewares = [
      {Tesla.Middleware.FormUrlencoded,
       encode: &Plug.Conn.Query.encode/1, decode: &Plug.Conn.Query.decode/1},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middlewares)
  end

  def refresh_token(refresh_token_string, provider \\ :google)

  def refresh_token(refresh_token_string, :google) do
    client_id = Application.fetch_env!(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_id]

    client_secret =
      Application.fetch_env!(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_secret]

    body = %{
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: refresh_token_string,
      grant_type: "refresh_token"
    }

    # Use Tesla to make the POST request
    case Tesla.post(client(), @google_token_url, body, opts: [form_urlencoded: true]) do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %Tesla.Env{status: status, body: error_body}} ->
        {:error, {status, error_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def refresh_token(refresh_token_string, :hubspot) do
    # HubSpot Strategy config might be under :ueberauth, Ueberauth.Strategy.Hubspot.OAuth
    # or just generic Ueberauth provider list.
    # Based on AuthController, it seems likely under standard Ueberauth config structure.
    # We'll try to fetch from Ueberauth.Strategy.Hubspot.OAuth first as assumed.

    config = Application.get_env(:ueberauth, Ueberauth.Strategy.Hubspot.OAuth)
    {client_id, client_secret} =
      if config do
        {config[:client_id], config[:client_secret]}
      else
        # Fallback to general provider config
        ueberauth_config = Application.get_env(:ueberauth, Ueberauth, [])
        hubspot_provider = Keyword.get(ueberauth_config, :providers, [])[:hubspot]
        # hubspot_provider is {Ueberauth.Strategy.Hubspot, [client_id: ..., ...]}
        {_strategy, opts} = hubspot_provider
        {opts[:client_id], opts[:client_secret]}
      end

    body = %{
      grant_type: "refresh_token",
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: refresh_token_string
    }

    case Tesla.post(client(), "https://api.hubapi.com/oauth/v1/token", body, opts: [form_urlencoded: true]) do
       {:ok, %Tesla.Env{status: 200, body: response_body}} ->
         {:ok, response_body}

       {:ok, %Tesla.Env{status: status, body: error_body}} ->
         {:error, {status, error_body}}

       {:error, reason} ->
         {:error, reason}
    end
  end
end
