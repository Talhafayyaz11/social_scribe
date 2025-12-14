defmodule SocialScribe.HubSpotTest do
  use ExUnit.Case, async: true

  alias SocialScribe.HubSpot

  @test_token "test_hubspot_token"

  describe "list_contacts/2" do
    test "returns contacts successfully" do
      # Mock successful response
      expected_contacts = [
        %{"id" => "1", "properties" => %{"firstname" => "John", "lastname" => "Doe"}},
        %{"id" => "2", "properties" => %{"firstname" => "Jane", "lastname" => "Smith"}}
      ]

      # Use Tesla.Mock for HTTP mocking
      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.hubapi.com/crm/v3/objects/contacts"} ->
          %Tesla.Env{
            status: 200,
            body: %{"results" => expected_contacts}
          }
      end)

      assert {:ok, contacts} = HubSpot.list_contacts(@test_token)
      assert length(contacts) == 2
      assert Enum.at(contacts, 0)["id"] == "1"
    end

    test "handles API errors" do
      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.hubapi.com/crm/v3/objects/contacts"} ->
          %Tesla.Env{
            status: 401,
            body: %{"message" => "Unauthorized"}
          }
      end)

      assert {:error, :list_failed} = HubSpot.list_contacts(@test_token)
    end

    test "handles connection errors" do
      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.hubapi.com/crm/v3/objects/contacts"} ->
          {:error, :timeout}
      end)

      assert {:error, :timeout} = HubSpot.list_contacts(@test_token)
    end

    test "respects limit parameter" do
      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.hubapi.com/crm/v3/objects/contacts", query: query} ->
          assert Keyword.get(query, :limit) == 50
          %Tesla.Env{status: 200, body: %{"results" => []}}
      end)

      HubSpot.list_contacts(@test_token, 50)
    end
  end

  describe "search_contacts/2" do
    test "returns search results successfully" do
      expected_results = [
        %{"id" => "1", "properties" => %{"firstname" => "John", "email" => "john@example.com"}}
      ]

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.hubapi.com/crm/v3/objects/contacts/search"} ->
          %Tesla.Env{status: 200, body: %{"results" => expected_results}}
      end)

      assert {:ok, results} = HubSpot.search_contacts("john", @test_token)
      assert length(results) == 1
    end

    test "returns empty results when no matches" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.hubapi.com/crm/v3/objects/contacts/search"} ->
          %Tesla.Env{status: 200, body: %{"results" => []}}
      end)

      assert {:ok, []} = HubSpot.search_contacts("nonexistent", @test_token)
    end

    test "handles search errors" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.hubapi.com/crm/v3/objects/contacts/search"} ->
          %Tesla.Env{status: 400, body: %{"message" => "Invalid filter"}}
      end)

      assert {:error, :search_failed} = HubSpot.search_contacts("test", @test_token)
    end

    test "searches by multiple fields (firstname, lastname, email)" do
      Tesla.Mock.mock(fn
        %{
          method: :post,
          url: "https://api.hubapi.com/crm/v3/objects/contacts/search",
          body: body_json
        } ->
          # Decode the JSON body
          body = Jason.decode!(body_json, keys: :atoms)

          # Verify filter groups contain all three fields
          assert length(body.filterGroups) == 3

          # Check that we have filters for all three fields
          filter_properties =
            body.filterGroups
            |> Enum.flat_map(fn fg -> fg.filters end)
            |> Enum.map(fn f -> f.propertyName end)

          assert "firstname" in filter_properties
          assert "lastname" in filter_properties
          assert "email" in filter_properties

          %Tesla.Env{status: 200, body: %{"results" => []}}
      end)

      HubSpot.search_contacts("test", @test_token)
    end
  end

  describe "get_contact/3" do
    test "fetches contact with default properties" do
      expected_contact = %{
        "id" => "123",
        "properties" => %{"firstname" => "John", "email" => "john@example.com"}
      }

      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.hubapi.com/crm/v3/objects/contacts/123"} ->
          %Tesla.Env{status: 200, body: expected_contact}
      end)

      assert {:ok, contact} = HubSpot.get_contact("123", @test_token)
      assert contact["id"] == "123"
    end

    test "fetches contact with all properties using search endpoint" do
      # First call to list all properties
      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.hubapi.com/crm/v3/properties/contacts"} ->
          %Tesla.Env{
            status: 200,
            body: %{
              "results" => [
                %{"name" => "firstname"},
                %{"name" => "lastname"},
                %{"name" => "email"}
              ]
            }
          }

        %{method: :post, url: "https://api.hubapi.com/crm/v3/objects/contacts/search"} ->
          %Tesla.Env{
            status: 200,
            body: %{
              "results" => [
                %{"id" => "123", "properties" => %{"firstname" => "John", "lastname" => "Doe"}}
              ]
            }
          }
      end)

      assert {:ok, contact} = HubSpot.get_contact("123", @test_token, "all")
      assert contact["id"] == "123"
    end

    test "fetches contact with specific properties list" do
      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.hubapi.com/crm/v3/objects/contacts/123", query: query} ->
          props = Keyword.get(query, :properties)
          assert props == "firstname,email"
          %Tesla.Env{status: 200, body: %{"id" => "123"}}
      end)

      HubSpot.get_contact("123", @test_token, ["firstname", "email"])
    end

    test "fetches contact with property string" do
      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.hubapi.com/crm/v3/objects/contacts/123", query: query} ->
          props = Keyword.get(query, :properties)
          assert props == "firstname,lastname"
          %Tesla.Env{status: 200, body: %{"id" => "123"}}
      end)

      HubSpot.get_contact("123", @test_token, "firstname,lastname")
    end

    test "handles not found error" do
      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.hubapi.com/crm/v3/objects/contacts/999"} ->
          %Tesla.Env{status: 404, body: %{"message" => "Contact not found"}}
      end)

      assert {:error, :get_failed} = HubSpot.get_contact("999", @test_token)
    end
  end

  describe "list_properties/1" do
    test "fetches all contact properties" do
      expected_properties = [
        %{"name" => "firstname", "type" => "string"},
        %{"name" => "email", "type" => "string"},
        %{"name" => "hs_language", "type" => "enumeration"}
      ]

      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.hubapi.com/crm/v3/properties/contacts"} ->
          %Tesla.Env{status: 200, body: %{"results" => expected_properties}}
      end)

      assert {:ok, properties} = HubSpot.list_properties(@test_token)
      assert length(properties) == 3
      assert "firstname" in properties
      assert "email" in properties
      assert "hs_language" in properties
    end

    test "handles API errors" do
      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.hubapi.com/crm/v3/properties/contacts"} ->
          %Tesla.Env{status: 500, body: %{"message" => "Server error"}}
      end)

      assert {:error, :list_props_failed} = HubSpot.list_properties(@test_token)
    end
  end

  describe "get_property_options/2" do
    test "fetches property metadata with enumeration options" do
      properties_response = [
        %{
          "name" => "hs_language",
          "type" => "enumeration",
          "fieldType" => "select",
          "options" => [
            %{"label" => "English", "value" => "en"},
            %{"label" => "Spanish", "value" => "es"}
          ]
        },
        %{
          "name" => "firstname",
          "type" => "string",
          "fieldType" => "text",
          "options" => []
        }
      ]

      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.hubapi.com/crm/v3/properties/contacts"} ->
          %Tesla.Env{status: 200, body: %{"results" => properties_response}}
      end)

      assert {:ok, metadata} =
               HubSpot.get_property_options(@test_token, ["hs_language", "firstname"])

      assert length(metadata) == 2

      language_meta = Enum.find(metadata, fn m -> m.name == "hs_language" end)
      assert language_meta.type == "enumeration"
      assert length(language_meta.options) == 2
      assert Enum.at(language_meta.options, 0).label == "English"
      assert Enum.at(language_meta.options, 0).value == "en"
    end

    test "fetches property metadata without options" do
      properties_response = [
        %{
          "name" => "firstname",
          "type" => "string",
          "fieldType" => "text"
        }
      ]

      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.hubapi.com/crm/v3/properties/contacts"} ->
          %Tesla.Env{status: 200, body: %{"results" => properties_response}}
      end)

      assert {:ok, [metadata]} = HubSpot.get_property_options(@test_token, ["firstname"])
      assert metadata.name == "firstname"
      assert metadata.options == []
    end

    test "handles API errors" do
      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.hubapi.com/crm/v3/properties/contacts"} ->
          %Tesla.Env{status: 403, body: %{"message" => "Forbidden"}}
      end)

      assert {:error, :list_props_failed} = HubSpot.get_property_options(@test_token, ["email"])
    end
  end

  describe "update_contact/3" do
    test "updates contact successfully" do
      updates = %{"firstname" => "Jane", "lastname" => "Doe"}

      expected_response = %{
        "id" => "123",
        "properties" => %{"firstname" => "Jane", "lastname" => "Doe"}
      }

      Tesla.Mock.mock(fn
        %{
          method: :patch,
          url: "https://api.hubapi.com/crm/v3/objects/contacts/123",
          body: body_json
        } ->
          # Decode the JSON body
          body = Jason.decode!(body_json, keys: :atoms)
          assert body.properties[:firstname] == "Jane"
          assert body.properties[:lastname] == "Doe"
          %Tesla.Env{status: 200, body: expected_response}
      end)

      assert {:ok, contact} = HubSpot.update_contact("123", updates, @test_token)
      assert contact["properties"]["firstname"] == "Jane"
    end

    test "handles validation errors" do
      Tesla.Mock.mock(fn
        %{method: :patch, url: "https://api.hubapi.com/crm/v3/objects/contacts/123"} ->
          %Tesla.Env{
            status: 400,
            body: %{"message" => "Invalid property value"}
          }
      end)

      assert {:error, :update_failed} =
               HubSpot.update_contact("123", %{"email" => "invalid"}, @test_token)
    end

    test "handles connection errors" do
      Tesla.Mock.mock(fn
        %{method: :patch, url: "https://api.hubapi.com/crm/v3/objects/contacts/123"} ->
          {:error, :econnrefused}
      end)

      assert {:error, :econnrefused} = HubSpot.update_contact("123", %{}, @test_token)
    end
  end
end
