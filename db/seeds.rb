# SUB-01 seeds: a handful of users and at least 10 url submissions with
# varied titles, links, authors, creation times and points.
#
# Idempotent: safe to run multiple times.

Submission.destroy_all
User.destroy_all

usernames = %w[pg patio11 tptacek jacquesm dang grellas cperciva tomhoward ingve luu]
users = usernames.map { |name| User.create!(username: name) }

submissions = [
  ["Show HN: I built a Rails clone of Hacker News", "https://github.com/example/hn-clone", 142],
  ["The modern web is a mess and here is why", "https://blog.example.com/modern-web-mess", 98],
  ["PostgreSQL 17 released", "https://www.postgresql.org/about/news/", 210],
  ["Why Ruby still matters in 2026", "https://example.org/ruby-2026", 76],
  ["A deep dive into how browsers render pages", "https://web.dev/rendering-deep-dive", 54],
  ["SQLite is all you need for most apps", "https://example.com/sqlite-enough", 187],
  ["The lost art of writing simple code", "https://example.net/simple-code", 63],
  ["How we cut our cloud bill by 80%", "https://startup.example.com/cloud-bill", 121],
  ["Understanding Rails 8 and Solid Queue", "https://railsnews.example.com/rails-8", 89],
  ["A beginner's guide to object storage", "https://docs.example.com/object-storage", 31],
  ["Type-safe configuration in large codebases", "https://news.example.com/type-safe-config", 45],
  ["The best developer tools nobody talks about", "https://tools.example.com/hidden-gems", 150]
]

submissions.each_with_index do |(title, url, points), i|
  Submission.create!(
    title: title,
    url: url,
    submission_type: "url",
    points: points,
    user: users.sample,
    created_at: (i * 7 + rand(1..6)).hours.ago
  )
end

ask_submissions = [
  ["Ask HN: What are you working on this week?", "Share your side projects.", 45],
  ["Ask HN: Best resources to learn Rails 8?", "Books, courses, tutorials welcome.", 28],
  ["Ask HN: How do you stay productive working remotely?", nil, 19]
]

ask_submissions.each_with_index do |(title, text, points), i|
  Submission.create!(
    title: title,
    text: text,
    submission_type: "ask",
    points: points,
    user: users.sample,
    created_at: (i * 5 + rand(1..4)).hours.ago
  )
end

puts "Seeded #{User.count} users and #{Submission.count} submissions " \
     "(#{Submission.of_type('url').count} url, #{Submission.of_type('ask').count} ask)."
