# frozen_string_literal: true

# This class represents single text inside an Ingestible.
# Each ingestible contains array of buffers serialized to json field works_buffer
class IngestibleText
  include ActiveModel::Model

  attr_accessor :content, :title
  attr_reader :secondary, :sefaria_linker

  def initialize(json)
    @title = json['title']
    @content = json['content']
    self.secondary = json['secondary']
    self.sefaria_linker = json['sefaria_linker']
  end

  # Values may arrive as checkbox strings ('0'/'1'), so cast to real booleans
  def secondary=(value)
    @secondary = ActiveModel::Type::Boolean.new.cast(value) || false
  end

  def sefaria_linker=(value)
    @sefaria_linker = ActiveModel::Type::Boolean.new.cast(value) || false
  end

  def to_hash
    {
      title: @title,
      content: @content,
      secondary: @secondary,
      sefaria_linker: @sefaria_linker
    }
  end
end
