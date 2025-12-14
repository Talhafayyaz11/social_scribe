defmodule SocialScribeWeb.MeetingLive.HubSpotUpdateComponent do
  use SocialScribeWeb, :live_component
  alias SocialScribe.HubSpot
  alias SocialScribe.Accounts

  @impl true
  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       search_query: "",
       all_contacts: [],
       displayed_contacts: [],
       selected_contact: nil,
       loading: true,
       initialized: false,
       show_dropdown: false,
       analyzing: false,
       suggestions: nil,
       property_metadata: [],
       selected_update_properties: MapSet.new(),
       collapsed_properties: MapSet.new()
     )}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if !socket.assigns.initialized && connected?(socket) do
      # Fetch contacts on initial load (client-side)
      case Accounts.get_user_hubspot_token(socket.assigns.current_user) do
        {:ok, token} ->
          case HubSpot.list_contacts(token) do
            {:ok, results} ->
              {:ok,
               assign(socket,
                 all_contacts: results,
                 displayed_contacts: results,
                 loading: false,
                 initialized: true
               )}

            {:error, _} ->
              {:ok,
               assign(socket,
                 all_contacts: [],
                 displayed_contacts: [],
                 loading: false,
                 initialized: true
               )
               |> put_flash(:error, "Failed to load HubSpot contacts.")}
          end

        {:error, _} ->
          {:ok, assign(socket, loading: false, initialized: true)}
      end
    else
      {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Update in HubSpot
        <:subtitle>
          Here are suggested updates to sync with your integrations based on this meeting
        </:subtitle>
      </.header>

      <div class="mt-6 space-y-6">
        <div class="relative" phx-click-away="close_dropdown" phx-target={@myself}>
          <label class="block text-sm font-medium text-gray-700 mb-1">Select Contact</label>
          <div class="relative">
            <%= if @selected_contact do %>
              <div
                class="w-full rounded-md border border-gray-300 shadow-sm px-3 py-2 bg-white flex items-center justify-between cursor-pointer hover:bg-gray-50"
                phx-click="clear_selection"
                phx-target={@myself}
              >
                <div class="flex items-center">
                  <span class="inline-flex items-center justify-center h-6 w-6 rounded-full bg-gray-200 text-xs font-medium text-gray-600 mr-2">
                    {initials(@selected_contact)}
                  </span>
                  <span class="text-sm font-medium text-gray-900">
                    {full_name(@selected_contact)}
                  </span>
                </div>
                <div class="flex flex-col ml-2">
                  <.icon name="hero-chevron-up-mini" class="h-3 w-3 text-gray-400" />
                  <.icon name="hero-chevron-down-mini" class="h-3 w-3 text-gray-400" />
                </div>
              </div>
            <% else %>
              <input
                type="text"
                class="w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                placeholder="Search HubSpot contacts..."
                value={@search_query}
                phx-keyup="search_contact"
                phx-focus="open_dropdown"
                phx-target={@myself}
                debounce="300"
                autocomplete="off"
              />
              <div :if={@loading} class="absolute right-3 top-2.5">
                <.icon name="hero-arrow-path" class="animate-spin h-5 w-5 text-gray-400" />
              </div>
            <% end %>
          </div>
          
    <!-- Dropdown Results -->
          <div
            :if={@show_dropdown && @displayed_contacts != [] && !@selected_contact}
            class="absolute z-10 mt-1 w-full bg-white shadow-lg max-h-60 rounded-md py-1 text-base ring-1 ring-black ring-opacity-5 overflow-auto focus:outline-none sm:text-sm"
          >
            <ul>
              <li
                :for={contact <- @displayed_contacts}
                phx-click="select_contact"
                phx-value-id={contact["id"]}
                phx-target={@myself}
                class="cursor-pointer select-none relative py-2 pl-3 pr-9 hover:bg-indigo-50 text-gray-900 group"
              >
                <div class="flex items-center">
                  <span class="inline-flex items-center justify-center h-8 w-8 rounded-full bg-gray-200 text-xs font-medium text-gray-600 mr-3">
                    {initials(contact)}
                  </span>
                  <span class="block truncate">
                    {full_name(contact)}
                    <span class="ml-2 text-gray-500 text-xs">({contact["properties"]["email"]})</span>
                  </span>
                </div>
              </li>
            </ul>
          </div>

          <p
            :if={
              @show_dropdown && @search_query != "" && @displayed_contacts == [] && !@selected_contact &&
                !@loading
            }
            class="mt-2 text-sm text-gray-500"
          >
            No contacts found.
          </p>
        </div>
        
    <!-- Analysis State -->
        <div :if={@analyzing} class="py-8 flex flex-col items-center justify-center text-center">
          <.icon name="hero-sparkles" class="h-8 w-8 text-indigo-500 animate-pulse mb-2" />
          <p class="text-sm font-medium text-gray-900">Analysing transcript...</p>
          <p class="text-xs text-gray-500">Comparing with HubSpot data</p>
        </div>

        <div :if={@suggestions && !@analyzing} class="flex flex-col h-[60vh]">
          <%= if Enum.empty?(@suggestions) do %>
            <div class="text-center py-4 text-gray-500 text-sm">
              No updates found in the transcript for this contact.
            </div>
          <% else %>
            <!-- Scrollable List -->
            <div class="flex-1 overflow-y-auto py-4 px-1 space-y-4 bg-white">
              <div
                :for={suggestion <- @suggestions}
                class="bg-gray-50 rounded-lg border border-gray-200 overflow-hidden"
              >
                <!-- Card Header -->
                <div class="p-4 flex items-center justify-between">
                  <div class="flex items-center gap-3">
                    <input
                      type="checkbox"
                      checked={MapSet.member?(@selected_update_properties, suggestion["property"])}
                      phx-click="toggle_property"
                      phx-value-property={suggestion["property"]}
                      phx-target={@myself}
                      class="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
                    />
                    <span class="font-semibold text-gray-900 capitalize">
                      {suggestion["property"] |> String.replace("_", " ")}
                    </span>
                  </div>

                  <div class="flex items-center gap-4">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-200 text-gray-800">
                      {if MapSet.member?(@selected_update_properties, suggestion["property"]),
                        do: "1",
                        else: "0"} update selected
                    </span>

                    <button
                      phx-click="toggle_details"
                      phx-value-property={suggestion["property"]}
                      phx-target={@myself}
                      class="text-sm text-gray-500 hover:text-gray-700 font-medium"
                    >
                      {if MapSet.member?(@collapsed_properties, suggestion["property"]),
                        do: "Show details",
                        else: "Hide details"}
                    </button>
                  </div>
                </div>
                
    <!-- Card Body -->
                <div
                  :if={!MapSet.member?(@collapsed_properties, suggestion["property"])}
                  class="p-4 pt-0 bg-gray-50"
                >
                  <div class="flex items-center gap-3 mb-2">
                    <div class="flex-1">
                      <div class="text-xs text-gray-500 mb-1">Old Value</div>
                      <div class="text-sm bg-white border border-gray-200 rounded px-2 py-1 text-gray-500 line-through">
                        {get_display_value(
                          suggestion["property"],
                          suggestion["old_value"],
                          @property_metadata
                        ) || "No existing value"}
                      </div>
                    </div>
                    <.icon name="hero-arrow-long-right" class="h-5 w-5 text-gray-400 self-center" />
                    <div class="flex-1">
                      <div class="text-xs text-gray-500 mb-1">New Value</div>
                      <div class="text-sm bg-white border border-indigo-300 ring-1 ring-indigo-300 rounded px-2 py-1 text-gray-900 font-medium">
                        {get_display_value(
                          suggestion["property"],
                          suggestion["new_value"],
                          @property_metadata
                        )}
                      </div>
                    </div>
                  </div>

                  <div class="flex items-center justify-between text-xs text-gray-500 mt-3">
                    <span>{suggestion["reason"]}</span>
                    <span class="text-indigo-600 font-medium">
                      Found in transcript ({suggestion["timestamp"]})
                    </span>
                  </div>

                  <div class="mt-2 text-xs text-indigo-600 hover:text-indigo-800 cursor-pointer">
                    Update mapping
                  </div>
                </div>
              </div>
            </div>
            
    <!-- Sticky Footer -->
            <div class="border-t border-gray-200 bg-white p-3 sticky bottom-0 z-10 flex items-center justify-between">
              <div class="text-sm text-gray-500">
                {length(@suggestions)} object{if length(@suggestions) != 1, do: "s", else: ""}, {length(
                  @suggestions
                )} fields selected to update
              </div>
              <div class="flex gap-3">
                <button
                  phx-click={JS.exec("data-cancel", to: "#hubspot-update-modal")}
                  class="rounded-md border border-gray-300 bg-white py-2 px-4 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                >
                  Cancel
                </button>
                <.button
                  disabled={!@suggestions || Enum.empty?(@selected_update_properties)}
                  phx-click="sync"
                  phx-target={@myself}
                  class="bg-emerald-500 hover:bg-emerald-600 disabled:bg-gray-300 disabled:cursor-not-allowed"
                >
                  Update HubSpot {if MapSet.size(@selected_update_properties) > 0,
                    do: "(#{MapSet.size(@selected_update_properties)})",
                    else: ""}
                </.button>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("open_dropdown", _, socket) do
    {:noreply, assign(socket, show_dropdown: true)}
  end

  @impl true
  def handle_event("close_dropdown", _, socket) do
    {:noreply, assign(socket, show_dropdown: false)}
  end

  @impl true
  def handle_event("search_contact", %{"value" => query}, socket) do
    # Client-side filtering
    normalized_query = String.downcase(query)

    filtered =
      if query == "" do
        socket.assigns.all_contacts
      else
        Enum.filter(socket.assigns.all_contacts, fn contact ->
          fname = String.downcase(contact["properties"]["firstname"] || "")
          lname = String.downcase(contact["properties"]["lastname"] || "")
          email = String.downcase(contact["properties"]["email"] || "")

          String.contains?(fname, normalized_query) ||
            String.contains?(lname, normalized_query) ||
            String.contains?(email, normalized_query)
        end)
      end

    {:noreply,
     assign(socket,
       search_query: query,
       displayed_contacts: filtered,
       selected_contact: nil,
       show_dropdown: true
     )}
  end

  @impl true
  def handle_event("select_contact", %{"id" => id}, socket) do
    contact = Enum.find(socket.assigns.all_contacts, fn c -> c["id"] == id end)

    # Trigger analysis in Parent LiveView
    send(self(), {:analyze_hubspot_contact, id})

    {:noreply,
     assign(socket,
       selected_contact: contact,
       displayed_contacts: [],
       search_query: "",
       show_dropdown: false,
       analyzing: true,
       suggestions: nil,
       selected_update_properties: MapSet.new()
     )}
  end

  def handle_event("clear_selection", _, socket) do
    # Reset to full list
    {:noreply,
     assign(socket,
       selected_contact: nil,
       search_query: "",
       displayed_contacts: socket.assigns.all_contacts,
       show_dropdown: true,
       analyzing: false,
       suggestions: nil
     )}
  end

  def handle_event("toggle_property", %{"property" => property}, socket) do
    selected = socket.assigns.selected_update_properties

    new_selected =
      if MapSet.member?(selected, property) do
        MapSet.delete(selected, property)
      else
        MapSet.put(selected, property)
      end

    {:noreply, assign(socket, selected_update_properties: new_selected)}
  end

  def handle_event("toggle_details", %{"property" => property}, socket) do
    collapsed = socket.assigns.collapsed_properties

    new_collapsed =
      if MapSet.member?(collapsed, property) do
        MapSet.delete(collapsed, property)
      else
        MapSet.put(collapsed, property)
      end

    {:noreply, assign(socket, collapsed_properties: new_collapsed)}
  end

  def handle_event("toggle_all", _, socket) do
    suggestions = socket.assigns.suggestions || []
    current_selected = socket.assigns.selected_update_properties
    all_count = length(suggestions)

    new_selected =
      if MapSet.size(current_selected) == all_count do
        MapSet.new()
      else
        MapSet.new(Enum.map(suggestions, & &1["property"]))
      end

    {:noreply, assign(socket, selected_update_properties: new_selected)}
  end

  def handle_event("sync", _, socket) do
    # Logic to send updates to parent or handle here
    # Since we need a token, we should probably do this in the parent task too, OR fetch token here again.
    # We already fetched token in mount. We can store it or fetch again.
    # Let's send a message to parent to perform update? Or do async task here.
    # Simpler to send to parent to keep token logic centralized if possible, but we did Accounts.get_token here.

    # Let's trigger a task in parent for consistency.

    updates =
      socket.assigns.suggestions
      |> Enum.filter(fn s ->
        MapSet.member?(socket.assigns.selected_update_properties, s["property"])
      end)
      |> Map.new(fn s -> {s["property"], s["new_value"]} end)

    send(self(), {:sync_hubspot_updates, socket.assigns.selected_contact["id"], updates})

    {:noreply,
     socket |> put_flash(:info, "Syncing updates...") |> push_patch(to: socket.assigns.patch)}
  end

  defp full_name(contact) do
    props = contact["properties"] || %{}
    "#{props["firstname"]} #{props["lastname"]}" |> String.trim()
  end

  defp initials(contact) do
    props = contact["properties"] || %{}
    f = String.first(props["firstname"] || "") || ""
    l = String.first(props["lastname"] || "") || ""
    "#{f}#{l}" |> String.upcase()
  end

  # Converts internal property value to display label for enumeration properties
  defp get_display_value(property_name, value, metadata) do
    # Find metadata for this property
    case Enum.find(metadata, fn m -> m.name == property_name end) do
      nil ->
        # No metadata found, return value as-is
        to_string(value)

      meta ->
        # Check if this property has enumeration options
        if meta.options != [] do
          # Find the option that matches this value
          case Enum.find(meta.options, fn opt -> opt.value == value end) do
            nil -> to_string(value)
            opt -> opt.label
          end
        else
          # Not an enumeration, return value as-is
          to_string(value)
        end
    end
  end
end
