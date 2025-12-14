defmodule SocialScribe.MeetingTranscriptExample do
  def meeting_transcript_example do
    [
      %{
        "words" => [
          %{
            "text" => "what I say later and then",
            "language" => nil,
            "start_timestamp" => 0.48204318,
            "end_timestamp" => 1.5677435,
            "confidence" => nil
          }
        ],
        "language" => "en-us",
        "participant" => %{
          "name" => "Felipe Gomes Paradas",
          "id" => 100,
          "is_host" => true
        },
        "speaker" => nil
      },
      %{
        "words" => [
          %{
            "text" => "It should be able to tell me.",
            "language" => nil,
            "start_timestamp" => 2.3654845,
            "end_timestamp" => 4.9698553,
            "confidence" => nil
          }
        ],
        "language" => "en-us",
        "participant" => %{
          "name" => "Felipe Gomes Paradas",
          "id" => 100,
          "is_host" => true
        },
        "speaker" => nil
      }
    ]
  end
end
