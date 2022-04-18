# frozen_string_literal: true

# name: reply_word_count
# about: Show the word count of topic replies not by OP
# version: 0.0.1
# authors: Alex Caudill
# url: www.heartsupport.com
# required_version: 2.7.0

enabled_site_setting :reply_word_count_enabled

PLUGIN_NAME ||= "reply_word_count_enabled".freeze

after_initialize do
  if SiteSetting.reply_word_count_enabled then
    add_to_serializer(:topic_view, :reply_word_count, false) {
      object.topic.reply_word_count
    }
  end

  register_topic_custom_field_type('reply_word_count', Integer)

  module ::DiscourseTopicReplyWordCount
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseTopicReplyWordCount
    end
  end

  class DiscourseTopicReplyWordCount::ReplyWordCount
    class << self
      # user is the OP of the topic.
      # We want OP posts subtracted from total word count.
      def reply_word_count(topic_id)
        DistributedMutex.synchronize("#{PLUGIN_NAME}-#{topic_id}") do
          topic = Topic.find_by_id(topic_id)
          user_id = topic.user_id

          # topic must not be deleted
          if topic.nil? || topic.trashed?
            raise StandardError.new I18n.t("topic.topic_is_deleted")
          end

          # topic must not be archived
          if topic.try(:archived)
            raise StandardError.new I18n.t("topic.topic_must_be_open_to_edit")
          end

          count = 0
          topic.posts.where("user_id != ?", user_id).each{|post| count += post.word_count}

          return count
        end
      end
    end
  end

  add_to_class(:topic, 'reply_word_count') do
    DiscourseTopicReplyWordCount::ReplyWordCount.reply_word_count(self.id)
  end

end
