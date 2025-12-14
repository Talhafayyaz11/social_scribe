defmodule SocialScribeWeb.AuthHTML do
  @moduledoc """
  This module handles rendering of authentication templates.
  """
  use SocialScribeWeb, :html

  embed_templates "templates/auth/*"
end
