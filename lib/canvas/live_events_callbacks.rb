# frozen_string_literal: true

#
# Copyright (C) 2018 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

module Canvas::LiveEventsCallbacks
  ELIGIBLE_ATTACHMENT_CONTEXTS = ['Course', 'Group', 'User'].freeze

  def self.after_create(obj)
    case obj
    when Course
      Canvas::LiveEvents.course_created(obj)
    when Conversation
      Canvas::LiveEvents.conversation_created(obj)
    when ConversationMessage
      Canvas::LiveEvents.conversation_message_created(obj)
    when DiscussionEntry
      Canvas::LiveEvents.discussion_entry_created(obj)
    when DiscussionTopic
      Canvas::LiveEvents.discussion_topic_created(obj)
    when Enrollment
      Canvas::LiveEvents.enrollment_created(obj)
    when EnrollmentState
      Canvas::LiveEvents.enrollment_state_created(obj)
    when Group
      Canvas::LiveEvents.group_created(obj)
    when GroupCategory
      Canvas::LiveEvents.group_category_created(obj)
    when GroupMembership
      Canvas::LiveEvents.group_membership_created(obj)
    when WikiPage
      Canvas::LiveEvents.wiki_page_created(obj)
    when Assignment
      Canvas::LiveEvents.assignment_created(obj)
    when AssignmentGroup
      Canvas::LiveEvents.assignment_group_created(obj)
    when AssignmentOverride
      Canvas::LiveEvents.assignment_override_created(obj)
    when Submission
      Canvas::LiveEvents.submission_created(obj) if obj.just_submitted?
    when SubmissionComment
      Canvas::LiveEvents.submission_comment_created(obj)
    when UserAccountAssociation
      Canvas::LiveEvents.user_account_association_created(obj)
    when Attachment
      if attachment_eligible?(obj)
        Canvas::LiveEvents.attachment_created(obj)
      end
    when AccountNotification
      Canvas::LiveEvents.account_notification_created(obj)
    when User
      Canvas::LiveEvents.user_created(obj)
    when CourseSection
      Canvas::LiveEvents.course_section_created(obj)
    when ContextModule
      Canvas::LiveEvents.module_created(obj)
    when ContentTag
      case obj.tag_type
      when 'context_module'
        Canvas::LiveEvents.module_item_created(obj)
      when 'learning_outcome_association'
        Canvas::LiveEvents.learning_outcome_link_created(obj)
      end
    when LearningOutcomeResult
      Canvas::LiveEvents.learning_outcome_result_created(obj)
    when LearningOutcome
      Canvas::LiveEvents.learning_outcome_created(obj)
    when LearningOutcomeGroup
      Canvas::LiveEvents.learning_outcome_group_created(obj)
    when SisBatch
      Canvas::LiveEvents.sis_batch_created(obj)
    when OutcomeProficiency
      Canvas::LiveEvents.outcome_proficiency_created(obj)
    when OutcomeCalculationMethod
      Canvas::LiveEvents.outcome_calculation_method_created(obj)
    when OutcomeFriendlyDescription
      Canvas::LiveEvents.outcome_friendly_description_created(obj)
    end
  end

  def self.after_update(obj, changes)
    case obj
    when ContentExport
      if obj.quizzes2_export? && changes["workflow_state"] && obj.workflow_state == "exported"
        Canvas::LiveEvents.quiz_export_complete(obj)
      end
    when ContentMigration
      if changes["workflow_state"] && obj.workflow_state == "imported"
        Canvas::LiveEvents.content_migration_completed(obj)
      end
    when Course
      if changes["syllabus_body"]
        Canvas::LiveEvents.course_syllabus_updated(obj, changes["syllabus_body"].first)
      end
      Canvas::LiveEvents.course_updated(obj)
    when DiscussionTopic
      Canvas::LiveEvents.discussion_topic_updated(obj)
    when Enrollment
      Canvas::LiveEvents.enrollment_updated(obj)
    when EnrollmentState
      if (changes.keys - ["state_is_current", "lock_version", "access_is_current"]).any?
        Canvas::LiveEvents.enrollment_state_updated(obj)
      end
    when GroupCategory
      Canvas::LiveEvents.group_category_updated(obj)
    when Group
      Canvas::LiveEvents.group_updated(obj)
    when GroupMembership
      Canvas::LiveEvents.group_membership_updated(obj)
    when WikiPage
      if changes["title"] || changes["body"]
        Canvas::LiveEvents.wiki_page_updated(obj, changes["title"] ? changes["title"].first : nil,
                                             changes["body"] ? changes["body"].first : nil)
      end
    when Assignment
      Canvas::LiveEvents.assignment_updated(obj)
    when AssignmentGroup
      Canvas::LiveEvents.assignment_group_updated(obj)
    when AssignmentOverride
      Canvas::LiveEvents.assignment_override_updated(obj)
    when Attachment
      if attachment_eligible?(obj)
        if changes["display_name"]
          Canvas::LiveEvents.attachment_updated(obj, changes["display_name"].first)
        elsif changes["file_state"] && obj.file_state == 'deleted'
          # Attachments are often soft deleted rather than destroyed
          Canvas::LiveEvents.attachment_deleted(obj)
        end
      end
    when Submission
      if obj.just_submitted?
        Canvas::LiveEvents.submission_created(obj)
      elsif !obj.unsubmitted?
        Canvas::LiveEvents.submission_updated(obj)
      end
    when User
      Canvas::LiveEvents.user_updated(obj)
    when CourseSection
      Canvas::LiveEvents.course_section_updated(obj)
    when ContextModule
      Canvas::LiveEvents.module_updated(obj)
    when ContextModuleProgression
      if changes["completed_at"]
        singleton_key = "course_progress_course_#{obj.context_module.global_context_id}_user_#{obj.global_user_id}"
        CourseProgress.delay_if_production(
          singleton: singleton_key,
          run_at: Setting.get('course_progress_live_event_delay_seconds', '120').to_i.seconds.from_now,
          on_conflict: :overwrite,
          priority: 15
        ).dispatch_live_event(obj)
      end
    when ContentTag
      case obj.tag_type
      when 'context_module'
        Canvas::LiveEvents.module_item_updated(obj)
      when 'learning_outcome_association'
        Canvas::LiveEvents.learning_outcome_link_updated(obj)
      end
    when LearningOutcomeResult
      Canvas::LiveEvents.learning_outcome_result_updated(obj)
    when LearningOutcome
      Canvas::LiveEvents.learning_outcome_updated(obj)
    when LearningOutcomeGroup
      Canvas::LiveEvents.learning_outcome_group_updated(obj)
    when SisBatch
      if changes[:workflow_state].present?
        Canvas::LiveEvents.sis_batch_updated(obj)
      end
    when OutcomeProficiency
      Canvas::LiveEvents.outcome_proficiency_updated(obj)
    when OutcomeCalculationMethod
      Canvas::LiveEvents.outcome_calculation_method_updated(obj)
    when OutcomeFriendlyDescription
      Canvas::LiveEvents.outcome_friendly_description_updated(obj)
    end
  end

  def self.after_destroy(obj)
    case obj
    when Attachment
      if attachment_eligible?(obj)
        Canvas::LiveEvents.attachment_deleted(obj)
      end
    when WikiPage
      Canvas::LiveEvents.wiki_page_deleted(obj)
    end
  end

  def self.attachment_eligible?(attachment)
    # We only send live events for attachments that would show up in Files
    # sections of Canvas.
    ELIGIBLE_ATTACHMENT_CONTEXTS.include?(attachment.context_type) &&
      attachment.folder_id.present?
  end
end
