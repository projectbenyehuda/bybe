# Email Throttling System

## Overview

The email throttling system allows users to control how frequently they receive notifications from the site. This prevents notification fatigue and gives users control over their inbox.

## User Options

Users can set their `email_frequency` preference to one of four values:

1. **unlimited** (default) - Receive notifications immediately in real-time
2. **daily** - Receive at most one digest email per day with all notifications
3. **weekly** - Receive at most one digest email per week with all notifications
4. **none** - Don't receive any email notifications from the site

## Implementation Details

### Models

- **BaseUser** - Extended with `email_frequency` preference using property_sets gem
- **PendingNotification** - Stores notifications that need to be sent in digest format

### Services

- **NotificationService** - Handles the logic of whether to send immediately or queue notifications based on user preferences

### Jobs

- **NotificationDigestJob** - Sidekiq job that runs on a schedule to send digest emails
  - Daily digests: Every day at 9:00 AM
  - Weekly digests: Every Monday at 9:00 AM

### Controllers

- **UserPreferencesController** - Allows users to manage their email frequency preference

### Email Footer

All notification emails now include a footer that:
- For registered users: Includes a link to manage their email preferences
- For non-registered users: Invites them to sign up to gain control over email frequency

## Usage

### For Developers

When sending a notification, use the `send_or_queue` class method instead of calling the mailer directly:

```ruby
# Old way (immediate send)
Notifications.tag_approved(tag).deliver

# New way (respects user preference)
Notifications.send_or_queue(:tag_approved, tag.creator.email, tag)
```

**Note on error handling**: The system handles nil emails gracefully - if the recipient email is blank, the notification is silently skipped. All existing notification code already checks for user.blocked? before sending, and many also check for valid email format. The send_or_queue method adds an additional check at the beginning to return early if recipient_email is blank.

The system will automatically:
1. Check if the recipient is a registered user
2. Check their email_frequency preference
3. Either send immediately, queue for digest, or suppress the notification

### For Users

Users can manage their email preferences by:
1. Logging in to the site
2. Navigating to `/user_preferences/edit`
3. Selecting their preferred email frequency
4. Saving their preferences

## Testing

Run the test suite:
```bash
docker compose run --rm test-app rspec spec/services/notification_service_spec.rb
docker compose run --rm test-app rspec spec/models/pending_notification_spec.rb
docker compose run --rm test-app rspec spec/controllers/user_preferences_controller_spec.rb
docker compose run --rm test-app rspec spec/sidekiq/notification_digest_job_spec.rb
```

Note: The NotificationDigestJob is placed in `app/sidekiq/` following the existing pattern in this codebase (see TagSimilarityJob).

## Migration

To enable this feature in a deployed environment:

1. Run the database migration:
   ```bash
   rails db:migrate
   ```

2. Restart the application and Sidekiq workers to pick up the new scheduler configuration
   
   The application uses rufus-scheduler (see `config/initializers/scheduler.rb`) to schedule recurring jobs. The digest jobs are configured to run:
   - Daily: Every 24 hours starting at 9:00 AM
   - Weekly: Every 7 days starting at 9:00 AM on Monday

3. All existing users will default to 'unlimited' (current behavior), so there's no disruption

## Future Enhancements

Possible improvements:
- Allow users to customize digest send time
- Add per-notification-type preferences (e.g., proofs vs tags)
- Email preview of what a digest would look like
- Unsubscribe links in emails
