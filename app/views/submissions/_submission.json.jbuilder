json.extract! submission, :id, :title, :url, :text, :submission_type, :points, :user_id, :created_at, :updated_at
json.url submission_url(submission, format: :json)
