defmodule SocialScribe.HubSpot do
  @behaviour SocialScribe.HubSpotApi
  require Logger

  defp client(token) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, "https://api.hubapi.com"},
      {Tesla.Middleware.Headers, [{"Authorization", "Bearer #{token}"}]},
      Tesla.Middleware.JSON
    ])
  end

  @impl true
  def list_contacts(token, limit \\ 100) do
    query = [
      limit: limit,
      properties: "firstname,lastname,email",
      archived: false
    ]

    case Tesla.get(client(token), "/crm/v3/objects/contacts", query: query) do
      {:ok, %{status: 200, body: %{"results" => results}}} ->
        {:ok, results}

      {:ok, response} ->
        Logger.error("HubSpot list contacts failed: #{inspect(response)}")
        {:error, :list_failed}

      {:error, reason} ->
        Logger.error("HubSpot request error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def search_contacts(query, token) do
    # CRM V3 Search Endpoint
    # We search by firstname, lastname, or email containing the query string.
    # "CONTAINS_TOKEN" is good for partial matches.
    # Note: Search filters are implicitly OR'd within a group if we structure logically,
    # but HubSpot default behavior for list of filters is AND?
    # Actually, CRM Search API `filters` array is AND.
    # To do OR, we need multiple `filterGroups`.

    body = %{
      filterGroups: [
        %{filters: [%{propertyName: "firstname", operator: "CONTAINS_TOKEN", value: query}]},
        %{filters: [%{propertyName: "lastname", operator: "CONTAINS_TOKEN", value: query}]},
        %{filters: [%{propertyName: "email", operator: "CONTAINS_TOKEN", value: query}]}
      ],
      properties: ["firstname", "lastname", "email"],
      limit: 20
    }

    case Tesla.post(client(token), "/crm/v3/objects/contacts/search", body) do
      {:ok, %{status: 200, body: %{"results" => results}}} ->
        {:ok, results}

      {:ok, response} ->
        Logger.error("HubSpot search failed: #{inspect(response)}")
        {:error, :search_failed}

      {:error, reason} ->
        Logger.error("HubSpot request error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def get_contact(contact_id, token, properties \\ nil) do
    # If no properties provided, fetch defaults. If "all", fetch all.
    case properties do
      "all" ->
        case list_properties(token) do
          {:ok, all_props} ->
            # Use search API (POST) to avoid query string limits
            search_body = %{
              filterGroups: [
                %{
                  filters: [
                    %{propertyName: "hs_object_id", operator: "EQ", value: contact_id}
                  ]
                }
              ],
              properties: all_props,
              limit: 1
            }

            case Tesla.post(client(token), "/crm/v3/objects/contacts/search", search_body) do
              {:ok, %{status: 200, body: %{"results" => [contact | _]}}} ->
                {:ok, contact}

              {:ok, %{status: 200, body: %{"results" => []}}} ->
                {:error, :not_found}

              {:ok, response} ->
                Logger.error("HubSpot search by ID failed: #{inspect(response)}")
                {:error, :get_failed}

              {:error, reason} ->
                Logger.error("HubSpot request error: #{inspect(reason)}")
                {:error, reason}
            end

          _ ->
            # Fallback to default GET if listing properties fails
            case Tesla.get(client(token), "/crm/v3/objects/contacts/#{contact_id}",
                   query: [properties: default_properties()]
                 ) do
              {:ok, %{status: 200, body: contact}} -> {:ok, contact}
              {:ok, _} -> {:error, :get_failed}
              {:error, reason} -> {:error, reason}
            end
        end

      nil ->
        case Tesla.get(client(token), "/crm/v3/objects/contacts/#{contact_id}",
               query: [properties: default_properties()]
             ) do
          {:ok, %{status: 200, body: contact}} -> {:ok, contact}
          other -> handle_get_response(other)
        end

      list when is_list(list) ->
        case Tesla.get(client(token), "/crm/v3/objects/contacts/#{contact_id}",
               query: [properties: Enum.join(list, ",")]
             ) do
          {:ok, %{status: 200, body: contact}} -> {:ok, contact}
          other -> handle_get_response(other)
        end

      str when is_binary(str) ->
        case Tesla.get(client(token), "/crm/v3/objects/contacts/#{contact_id}",
               query: [properties: str]
             ) do
          {:ok, %{status: 200, body: contact}} -> {:ok, contact}
          other -> handle_get_response(other)
        end
    end
  end

  defp handle_get_response(response) do
    case response do
      {:ok, %{status: 200, body: contact}} ->
        {:ok, contact}

      {:ok, response} ->
        Logger.error("HubSpot get contact failed: #{inspect(response)}")
        {:error, :get_failed}

      {:error, reason} ->
        Logger.error("HubSpot request error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def list_properties(token) do
    case Tesla.get(client(token), "/crm/v3/properties/contacts") do
      {:ok, %{status: 200, body: %{"results" => results}}} ->
        prop_names = Enum.map(results, & &1["name"])
        {:ok, prop_names}

      {:ok, response} ->
        Logger.error("HubSpot list properties failed: #{inspect(response)}")
        {:error, :list_props_failed}

      {:error, reason} ->
        Logger.error("HubSpot request error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_property_options(token, properties) do
    case Tesla.get(client(token), "/crm/v3/properties/contacts") do
      {:ok, %{status: 200, body: %{"results" => results}}} ->
        # Filter for requested properties and extract type/options
        metadata =
          results
          |> Enum.filter(fn p -> p["name"] in properties end)
          |> Enum.map(fn p ->
            options =
              if is_list(p["options"]) do
                Enum.map(p["options"], fn opt ->
                  %{label: opt["label"], value: opt["value"]}
                end)
              else
                []
              end

            %{
              name: p["name"],
              type: p["type"],
              field_type: p["fieldType"],
              options: options
            }
          end)

        {:ok, metadata}

      {:ok, response} ->
        Logger.error("HubSpot list properties failed: #{inspect(response)}")
        {:error, :list_props_failed}

      {:error, reason} ->
        Logger.error("HubSpot request error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp default_properties do
    "hs_object_id,firstname,lastname,email,phone,jobtitle,hubspot_owner_id,support_priority,hs_language,product_purchased,company,account_value,notes_last_contacted"
  end

  @impl true
  def update_contact(contact_id, properties, token) do
    body = %{properties: properties}

    case Tesla.patch(client(token), "/crm/v3/objects/contacts/#{contact_id}", body) do
      {:ok, %{status: 200, body: contact}} ->
        {:ok, contact}

      {:ok, response} ->
        Logger.error("HubSpot update contact failed: #{inspect(response)}")
        {:error, :update_failed}

      {:error, reason} ->
        Logger.error("HubSpot request error: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
