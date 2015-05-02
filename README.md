# simpleAppReviewReporter

This simple scripts get reviews from GooglePlay or AppStore.
And provide simple hipchat class.

# Quick Start

```
$ bundle install
$ ruby app_review_script.rb
```

- `app_review_script.rb`

```ruby
require './app_review.rb'

google_reporter = AppReview::GooglePlay.new('com.android.chrome', 'jp')
google_result = google_reporter.latest_reviews_upto 5

app_reporter = AppReview::AppStore.new('375380948', 'jp')
app_result = app_reporter.latest_reviews_upto 5

hipchat = HipChat.new(TOKEN)
hipchat.report(google_result, room_id)
hipchat.report(app_result, room_id)
```


# License

Please see LICENSE