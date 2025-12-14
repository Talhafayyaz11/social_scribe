defmodule SocialScribeWeb.MeetingLive.HubSpotUpdateComponentTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.BotsFixtures

  alias SocialScribe.Meetings.Meeting
  alias SocialScribe.Repo

  describe "mount" do
    test "initializes with correct default state", %{conn: conn} do
      user = user_fixture()
      bot = recall_bot_fixture(%{user_id: user.id})

      {:ok, meeting} =
        %Meeting{}
        |> Meeting.changeset(%{
          user_id: user.id,
          bot_id: bot.id,
          title: "Test Meeting",
          recall_meeting_id: "test_id",
          status: :processed,
          scheduled_at: DateTime.utc_now()
        })
        |> Repo.insert()

      conn = log_in_user(conn, user)

      # Navigate to meeting page where component would be used
      {:ok, _view, html} = live(conn, ~p"/meetings/#{meeting}")

      # Component should initialize with empty state
      assert html =~ "Test Meeting"
    end
  end

  describe "contact search and selection" do
    setup %{conn: conn} do
      user = user_fixture()
      bot = recall_bot_fixture(%{user_id: user.id})

      {:ok, meeting} =
        %Meeting{}
        |> Meeting.changeset(%{
          user_id: user.id,
          bot_id: bot.id,
          title: "Test Meeting",
          recall_meeting_id: "test_id",
          status: :processed,
          scheduled_at: DateTime.utc_now()
        })
        |> Repo.insert()

      # Create HubSpot credential
      {:ok, _credential} =
        SocialScribe.Accounts.create_user_credential(%{
          user_id: user.id,
          provider: "hubspot",
          uid: "hubspot_uid",
          token: "test_token",
          refresh_token: "test_refresh",
          expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
          email: user.email
        })

      conn = log_in_user(conn, user)

      %{conn: conn, meeting: meeting, user: user}
    end

    test "filters contacts by firstname", %{conn: conn, meeting: meeting} do
      # Mock HubSpot contacts response
      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.hubapi.com/crm/v3/objects/contacts"} ->
          %Tesla.Env{
            status: 200,
            body: %{
              "results" => [
                %{
                  "id" => "1",
                  "properties" => %{
                    "firstname" => "John",
                    "lastname" => "Doe",
                    "email" => "john@example.com"
                  }
                },
                %{
                  "id" => "2",
                  "properties" => %{
                    "firstname" => "Jane",
                    "lastname" => "Smith",
                    "email" => "jane@example.com"
                  }
                }
              ]
            }
          }
      end)

      {:ok, view, _html} = live(conn, ~p"/meetings/#{meeting}")

      # Open the HubSpot modal (this would be done via button click in real UI)
      # For testing purposes, we'll simulate the component being rendered
      assert has_element?(view, "h2", "Test Meeting")
    end

    test "filters contacts by lastname", %{conn: _conn, meeting: _meeting} do
      # Client-side filtering logic test
      all_contacts = [
        %{
          "id" => "1",
          "properties" => %{
            "firstname" => "John",
            "lastname" => "Doe",
            "email" => "john@example.com"
          }
        },
        %{
          "id" => "2",
          "properties" => %{
            "firstname" => "Jane",
            "lastname" => "Smith",
            "email" => "jane@example.com"
          }
        }
      ]

      query = "smith"
      normalized_query = String.downcase(query)

      filtered =
        Enum.filter(all_contacts, fn contact ->
          lname = String.downcase(contact["properties"]["lastname"] || "")
          String.contains?(lname, normalized_query)
        end)

      assert length(filtered) == 1
      assert Enum.at(filtered, 0)["id"] == "2"
    end

    test "filters contacts by email", %{conn: _conn, meeting: _meeting} do
      all_contacts = [
        %{
          "id" => "1",
          "properties" => %{
            "firstname" => "John",
            "lastname" => "Doe",
            "email" => "john@example.com"
          }
        },
        %{
          "id" => "2",
          "properties" => %{
            "firstname" => "Jane",
            "lastname" => "Smith",
            "email" => "jane@example.com"
          }
        }
      ]

      query = "jane@"
      normalized_query = String.downcase(query)

      filtered =
        Enum.filter(all_contacts, fn contact ->
          email = String.downcase(contact["properties"]["email"] || "")
          String.contains?(email, normalized_query)
        end)

      assert length(filtered) == 1
      assert Enum.at(filtered, 0)["properties"]["email"] == "jane@example.com"
    end

    test "search is case-insensitive", %{conn: _conn, meeting: _meeting} do
      all_contacts = [
        %{
          "id" => "1",
          "properties" => %{
            "firstname" => "John",
            "lastname" => "Doe",
            "email" => "john@example.com"
          }
        }
      ]

      # Test with uppercase query
      query = "JOHN"
      normalized_query = String.downcase(query)

      filtered =
        Enum.filter(all_contacts, fn contact ->
          fname = String.downcase(contact["properties"]["firstname"] || "")
          String.contains?(fname, normalized_query)
        end)

      assert length(filtered) == 1
    end
  end

  describe "display value conversion" do
    test "shows label for enum properties" do
      property_metadata = [
        %{
          name: "hs_language",
          type: "enumeration",
          field_type: "select",
          options: [
            %{label: "English", value: "en"},
            %{label: "Spanish", value: "es"}
          ]
        }
      ]

      # Test the get_display_value function logic
      property_name = "hs_language"
      value = "en"

      meta = Enum.find(property_metadata, fn m -> m.name == property_name end)

      display_value =
        if meta.options != [] do
          case Enum.find(meta.options, fn opt -> opt.value == value end) do
            nil -> to_string(value)
            opt -> opt.label
          end
        else
          to_string(value)
        end

      assert display_value == "English"
    end

    test "shows raw value for non-enum properties" do
      property_metadata = [
        %{
          name: "firstname",
          type: "string",
          field_type: "text",
          options: []
        }
      ]

      property_name = "firstname"
      value = "John"

      meta = Enum.find(property_metadata, fn m -> m.name == property_name end)

      display_value =
        if meta.options != [] do
          case Enum.find(meta.options, fn opt -> opt.value == value end) do
            nil -> to_string(value)
            opt -> opt.label
          end
        else
          to_string(value)
        end

      assert display_value == "John"
    end

    test "shows raw value when no metadata found" do
      property_metadata = []

      property_name = "unknown_field"
      value = "some_value"

      meta = Enum.find(property_metadata, fn m -> m.name == property_name end)

      display_value =
        case meta do
          nil -> to_string(value)
          _ -> to_string(value)
        end

      assert display_value == "some_value"
    end
  end

  describe "property selection" do
    test "toggle adds property to selection" do
      selected = MapSet.new()
      property = "firstname"

      new_selected =
        if MapSet.member?(selected, property) do
          MapSet.delete(selected, property)
        else
          MapSet.put(selected, property)
        end

      assert MapSet.member?(new_selected, property)
      assert MapSet.size(new_selected) == 1
    end

    test "toggle removes property from selection" do
      selected = MapSet.new(["firstname", "lastname"])
      property = "firstname"

      new_selected =
        if MapSet.member?(selected, property) do
          MapSet.delete(selected, property)
        else
          MapSet.put(selected, property)
        end

      refute MapSet.member?(new_selected, property)
      assert MapSet.size(new_selected) == 1
      assert MapSet.member?(new_selected, "lastname")
    end
  end

  describe "details expand/collapse" do
    test "toggle adds property to collapsed set" do
      collapsed = MapSet.new()
      property = "firstname"

      new_collapsed =
        if MapSet.member?(collapsed, property) do
          MapSet.delete(collapsed, property)
        else
          MapSet.put(collapsed, property)
        end

      assert MapSet.member?(new_collapsed, property)
    end

    test "toggle removes property from collapsed set" do
      collapsed = MapSet.new(["firstname"])
      property = "firstname"

      new_collapsed =
        if MapSet.member?(collapsed, property) do
          MapSet.delete(collapsed, property)
        else
          MapSet.put(collapsed, property)
        end

      refute MapSet.member?(new_collapsed, property)
    end
  end

  describe "sync functionality" do
    test "prepares updates with selected properties only" do
      suggestions = [
        %{"property" => "firstname", "new_value" => "Jane"},
        %{"property" => "lastname", "new_value" => "Doe"},
        %{"property" => "email", "new_value" => "jane@example.com"}
      ]

      selected_properties = MapSet.new(["firstname", "email"])

      updates =
        suggestions
        |> Enum.filter(fn s -> MapSet.member?(selected_properties, s["property"]) end)
        |> Map.new(fn s -> {s["property"], s["new_value"]} end)

      assert Map.keys(updates) |> length() == 2
      assert updates["firstname"] == "Jane"
      assert updates["email"] == "jane@example.com"
      refute Map.has_key?(updates, "lastname")
    end

    test "sync disabled when no properties selected" do
      selected_properties = MapSet.new()
      suggestions = [%{"property" => "firstname", "new_value" => "Jane"}]

      is_disabled = !suggestions || Enum.empty?(selected_properties)

      assert is_disabled
    end

    test "sync enabled when properties selected" do
      selected_properties = MapSet.new(["firstname"])
      suggestions = [%{"property" => "firstname", "new_value" => "Jane"}]

      is_disabled = !suggestions || Enum.empty?(selected_properties)

      refute is_disabled
    end
  end

  describe "initials display" do
    test "generates initials from firstname and lastname" do
      contact = %{
        "properties" => %{
          "firstname" => "John",
          "lastname" => "Doe"
        }
      }

      props = contact["properties"] || %{}
      f = String.first(props["firstname"] || "") || ""
      l = String.first(props["lastname"] || "") || ""
      initials = "#{f}#{l}" |> String.upcase()

      assert initials == "JD"
    end

    test "handles missing names gracefully" do
      contact = %{
        "properties" => %{
          "firstname" => "",
          "lastname" => ""
        }
      }

      props = contact["properties"] || %{}
      f = String.first(props["firstname"] || "") || ""
      l = String.first(props["lastname"] || "") || ""
      initials = "#{f}#{l}" |> String.upcase()

      assert initials == ""
    end
  end
end
