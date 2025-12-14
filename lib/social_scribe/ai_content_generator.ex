defmodule SocialScribe.AIContentGenerator do
  @moduledoc "Generates content using Google Gemini."

  @behaviour SocialScribe.AIContentGeneratorApi

  alias SocialScribe.Meetings
  alias SocialScribe.Automations
  alias SocialScribe.HubSpot

  require Logger

  @gemini_model "gemini-2.5-flash"
  @gemini_api_base_url "https://generativelanguage.googleapis.com/v1beta/models"

  @impl SocialScribe.AIContentGeneratorApi
  def generate_follow_up_email(meeting) do
    case Meetings.generate_prompt_for_meeting(meeting) do
      {:error, reason} ->
        {:error, reason}

      {:ok, meeting_prompt} ->
        prompt = """
        Based on the following meeting transcript, please draft a concise and professional follow-up email.
        The email should summarize the key discussion points and clearly list any action items assigned, including who is responsible if mentioned.
        Keep the tone friendly and action-oriented.

        #{meeting_prompt}
        """

        call_gemini(prompt)
    end
  end

  @impl SocialScribe.AIContentGeneratorApi
  def generate_automation(automation, meeting) do
    case Meetings.generate_prompt_for_meeting(meeting) do
      {:error, reason} ->
        {:error, reason}

      {:ok, meeting_prompt} ->
        prompt = """
        #{Automations.generate_prompt_for_automation(automation)}

        #{meeting_prompt}
        """

        call_gemini(prompt)
    end
  end

  alias SocialScribe.HubSpot

  def suggest_hubspot_updates(meeting, contact, token) do
    case Meetings.get_transcript_with_timestamps(meeting) do
      {:error, reason} ->
        {:error, reason}

      {:ok, transcript} ->
        contact_props = contact["properties"] || %{}
        contact_json = Jason.encode!(contact_props)

        # Extract contact identity for speaker matching
        contact_name = get_contact_full_name(contact_props)
        contact_email = contact_props["email"] || "unknown"

        # Get meeting participants for context
        participants_list = format_participants_list(meeting.meeting_participants)

        # Fetch property metadata for validation info
        prop_keys = Map.keys(contact_props)

        # Fetch property metadata for validation
        property_metadata_result = HubSpot.get_property_options(token, prop_keys)

        validation_info =
          case property_metadata_result do
            {:ok, metadata} ->
              metadata
              |> Enum.map(fn meta ->
                options_str =
                  if meta.options != [] do
                    opts_list =
                      Enum.map(meta.options, fn o ->
                        "\"#{o.label}\" (Internal Value: \"#{o.value}\")"
                      end)

                    "Allowed Options: #{Enum.join(opts_list, ", ")}"
                  else
                    ""
                  end

                type_str = "Type: #{meta.type}"
                "#{meta.name}: #{type_str} #{options_str}"
              end)
              |> Enum.join("\n")

            _ ->
              ""
          end

        prompt = """
        You are a CRM assistant analyzing a meeting transcript to update HubSpot contact records.

        ## SELECTED CONTACT TO UPDATE:
        Name: #{contact_name}
        Email: #{contact_email}

        ## MEETING PARTICIPANTS:
        #{participants_list}

        ## CRITICAL SPEAKER ATTRIBUTION RULES:
        1. **ONLY suggest updates** for information that was explicitly stated BY or ABOUT "#{contact_name}".
        2. Use fuzzy name matching: "#{contact_name}" might be referred to as just their first name, nickname, or slight variations.
        3. **DO NOT suggest updates** based on information about OTHER participants in the meeting.
        4. If "#{contact_name}" was NOT mentioned or referenced in the transcript (directly or indirectly), return an EMPTY array [].
        5. In the "reason" field, include WHO mentioned this information (e.g., "John Smith stated..." or "Sarah mentioned about #{contact_name}...").

        ## Current Contact Data (JSON):
        #{contact_json}

        ## Property Validation Rules:
        #{validation_info}

        ## Meeting Transcript (with timestamps and speaker names):
        #{transcript}

        ## Instructions:
        1. Analyze the transcript for any specific information about "#{contact_name}" that is different from or missing in the "Current Contact Data".
        2. Consider ALL properties provided in the "Current Contact Data". Do not limit yourself to standard fields.
        3. Ignore minor conversational variations (e.g., "Mike" vs "Michael") unless explicitly corrected.
        4. If you find a relevant update for "#{contact_name}", create a suggestion.
        5. CRITICAL: Respect the "Property Validation Rules" above.
           - If a property is an enumeration (has Allowed Options):
             - You MUST select the most appropriate option based on the transcript.
             - **CRITICAL**: The "new_value" in your JSON output MUST be the "Internal Value" (e.g. if option is "English (Internal Value: en)", output "en"). DO NOT output the label ("English").
           - If a property is a 'number', return only the numeric value (e.g., 10000 not "10,000" or "$10,000").
           - If the transcript value doesn't match an allowed option/type, DO NOT suggest an update for that property.

        ## Output Format:
        Return ONLY a raw JSON array of objects (no markdown formatting). Each object must have:
        - "property": The HubSpot property name (e.g., "jobtitle").
        - "old_value": The value from the current data (or null if missing).
        - "new_value": The internal value found in the transcript (must match validation rules).
        - "reason": A brief explanation including who mentioned this (e.g., "John Smith stated his new phone number is...").
        - "timestamp": The timestamp from the transcript where this info was found (e.g., "12:45").

        REMEMBER: Return [] if "#{contact_name}" was not referenced in the transcript.
        """

        case call_gemini(prompt) do
          {:ok, response_text} ->
            # Clean up potential markdown code blocks
            cleaned_text =
              response_text
              |> String.replace(~r/^```json\s*/, "")
              |> String.replace(~r/\s*```$/, "")
              |> String.trim()

            case Jason.decode(cleaned_text) do
              {:ok, suggestions} when is_list(suggestions) ->
                Logger.info("AI generated #{length(suggestions)} suggestions before validation")
                Logger.debug("Raw AI suggestions: #{inspect(suggestions)}")

                # Validate suggestions against property metadata
                validated_suggestions =
                  case property_metadata_result do
                    {:ok, metadata} ->
                      Logger.info(
                        "Validating suggestions with #{length(metadata)} property metadata entries"
                      )

                      result = validate_suggestions(suggestions, metadata)
                      Logger.info("After validation: #{length(result)} suggestions remain")
                      result

                    _ ->
                      # If we couldn't fetch metadata, return suggestions as-is
                      # (better to show them than fail completely)
                      Logger.warning(
                        "Could not validate AI suggestions - property metadata unavailable"
                      )

                      suggestions
                  end

                # Return both suggestions and metadata for UI label conversion
                metadata_list =
                  case property_metadata_result do
                    {:ok, metadata} -> metadata
                    _ -> []
                  end

                {:ok, %{suggestions: validated_suggestions, metadata: metadata_list}}

              {:ok, _} ->
                {:error, :invalid_response_format}

              {:error, _} ->
                {:error, :json_decoding_failed}
            end

          error ->
            error
        end
    end
  end

  require Logger

  # Validates AI-generated suggestions against HubSpot property metadata
  # Filters out suggestions with invalid enumeration values or incorrect types
  defp validate_suggestions(suggestions, metadata) do
    # Create a map of property_name -> metadata for quick lookup
    metadata_map = Map.new(metadata, fn meta -> {meta.name, meta} end)

    suggestions
    |> Enum.filter(fn suggestion ->
      property_name = suggestion["property"]
      old_value = suggestion["old_value"]
      new_value = suggestion["new_value"]

      # First check if values are effectively the same (despite type differences)
      if values_equal?(old_value, new_value) do
        Logger.info(
          "Filtered no-op AI suggestion: property=#{property_name}, " <>
            "old=#{inspect(old_value)}, new=#{inspect(new_value)} (values are the same)"
        )

        false
      else
        case Map.get(metadata_map, property_name) do
          nil ->
            # Property not in metadata - allow it through
            # (it might be a valid property we just didn't fetch metadata for)
            true

          meta ->
            valid = validate_property_value(meta, new_value)

            if !valid do
              Logger.warning(
                "Filtered invalid AI suggestion: property=#{property_name}, " <>
                  "value=#{inspect(new_value)}, type=#{meta.type}, " <>
                  "options=#{inspect(Enum.map(meta.options, & &1.value))}"
              )
            end

            valid
        end
      end
    end)
  end

  # Validates a single property value against its metadata
  defp validate_property_value(meta, new_value) do
    cond do
      # If property has enumeration options, validate against them
      meta.options != [] ->
        allowed_values = Enum.map(meta.options, & &1.value)
        new_value in allowed_values

      # If property is a number type, validate it's numeric
      meta.type == "number" ->
        is_number(new_value) or is_numeric_string?(new_value)

      # For other types (string, etc.), accept any value
      true ->
        true
    end
  end

  # Checks if a string can be parsed as a number
  defp is_numeric_string?(value) when is_binary(value) do
    case Float.parse(value) do
      {_, ""} -> true
      _ -> false
    end
  end

  defp is_numeric_string?(_), do: false

  # Checks if two values are effectively equal, normalizing for type differences
  # For example, "1" (string) and 1 (integer) are considered equal
  defp values_equal?(val1, val2) do
    # Direct equality check first
    if val1 == val2 do
      true
    else
      # Try normalizing both values and compare
      normalize_value(val1) == normalize_value(val2)
    end
  end

  # Normalizes a value for comparison
  # Converts numeric strings to numbers, handles nil/null
  defp normalize_value(nil), do: nil
  defp normalize_value(""), do: nil

  defp normalize_value(value) when is_binary(value) do
    # Try to parse as number
    case Float.parse(value) do
      {num, ""} ->
        # If it's a whole number, convert to integer
        if num == trunc(num) do
          trunc(num)
        else
          num
        end

      _ ->
        # Not a number, return lowercased string for case-insensitive comparison
        String.downcase(String.trim(value))
    end
  end

  defp normalize_value(value) when is_number(value), do: value
  defp normalize_value(value), do: value

  # Extracts full name from HubSpot contact properties
  defp get_contact_full_name(contact_props) do
    first_name = contact_props["firstname"] || ""
    last_name = contact_props["lastname"] || ""
    "#{first_name} #{last_name}" |> String.trim()
  end

  # Formats meeting participants list for AI context
  defp format_participants_list(participants) when is_list(participants) do
    if Enum.empty?(participants) do
      "(No participant data available)"
    else
      participants
      |> Enum.map(fn p ->
        role = if p.is_host, do: "Host", else: "Participant"
        "- #{p.name} (#{role})"
      end)
      |> Enum.join("\n")
    end
  end

  defp format_participants_list(_), do: "(No participant data available)"

  defp call_gemini(prompt_text) do
    api_key = Application.fetch_env!(:social_scribe, :gemini_api_key)
    url = "#{@gemini_api_base_url}/#{@gemini_model}:generateContent?key=#{api_key}"

    payload = %{
      contents: [
        %{
          parts: [%{text: prompt_text}]
        }
      ]
    }

    Logger.info("Sending request to Gemini model #{@gemini_model}...")
    Logger.debug("Gemini Prompt: #{prompt_text}")

    case Tesla.post(client(), url, payload) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        # Safely extract the text content
        # The response structure is typically: body.candidates[0].content.parts[0].text

        text_path = [
          "candidates",
          Access.at(0),
          "content",
          "parts",
          Access.at(0),
          "text"
        ]

        case get_in(body, text_path) do
          nil ->
            Logger.error("Gemini Response (No Text Found): #{inspect(body)}")
            {:error, {:parsing_error, "No text content found in Gemini response", body}}

          text_content ->
            Logger.info("Gemini Raw Response: #{text_content}")
            {:ok, text_content}
        end

      {:ok, %Tesla.Env{status: status, body: error_body}} ->
        Logger.error("Gemini API Error (#{status}): #{inspect(error_body)}")
        {:error, {:api_error, status, error_body}}

      {:error, reason} ->
        Logger.error("Gemini HTTP Error: #{inspect(reason)}")
        {:error, {:http_error, reason}}
    end
  end

  defp client do
    middleware = [
      {Tesla.Middleware.BaseUrl, @gemini_api_base_url},
      {Tesla.Middleware.Timeout, timeout: 360_000},
      Tesla.Middleware.JSON
    ]

    adapter = {Tesla.Adapter.Hackney, [recv_timeout: 360_000]}

    Tesla.client(middleware, adapter)
  end
end
