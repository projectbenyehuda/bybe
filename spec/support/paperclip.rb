# frozen_string_literal: true

# Paperclip attachments (e.g. Authority#profile_image) are configured to use S3 storage.
# Factories such as `create(:authority, :with_image)` only set the *_file_name column, so no
# file is ever uploaded, but destroying such a record still makes Paperclip reach out to S3 to
# delete the (non-existent) object. Under WebMock/VCR that raises UnhandledHTTPRequestError,
# which aborts `clean_tables` and leaves records behind, poisoning every subsequent spec that
# cleans the database.
#
# Preserving files on destroy keeps URL generation unchanged while making destroys purely local.
Paperclip::Attachment.default_options[:preserve_files] = true
