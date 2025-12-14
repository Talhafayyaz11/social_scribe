defmodule SocialScribe.HubSpotApi do
  @callback search_contacts(String.t(), String.t()) :: {:ok, list(map())} | {:error, any()}
  @callback list_contacts(String.t(), integer()) :: {:ok, list(map())} | {:error, any()}
  @callback get_contact(String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  @callback update_contact(String.t(), map(), String.t()) :: {:ok, map()} | {:error, any()}
  @callback list_properties(String.t()) :: {:ok, list(String.t())} | {:error, any()}
  @callback get_property_options(String.t(), list(String.t())) ::
              {:ok, list(map())} | {:error, any()}
end
