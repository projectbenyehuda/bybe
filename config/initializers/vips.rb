# frozen_string_literal: true

# Rails 8.1.3.1 disabled libvips's "untrusted" loaders and savers at boot
# (ActiveStorage calls Vips.block_untrusted(true)), which also disables the ImageMagick bindings.
# This affects loading of BMP (as well as ICO and PSD) attachments, which are loaded through ImageMagick
# rather than libvips itself.

# E.g. when we tried to generate a variant of a BMP attachment, we got an error:
# VipsForeignLoad: "<filename>" is not a known file format (Vips::Error)

# see https://github.com/rails/rails/blob/v8.1.4/activestorage/CHANGELOG.md#rails-8131-july-29-2026

# Re-enable the ImageMagick bindings so that BMP (as well as ICO and PSD) attachments can be processed.
require 'active_storage/vips'
# TODO: consider removing this initializer we don't need to support BMP/ICO/PSD attachments anymore
Vips.block('VipsForeignLoadMagick7', false) # enable ImageMagick 7 loaders
