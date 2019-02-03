# frozen_string_literal: true

module EE
  module GroupsHelper
    extend ::Gitlab::Utils::Override

    override :group_overview_nav_link_paths
    def group_overview_nav_link_paths
      super + %w(groups/security/dashboard#show)
    end

    override :group_nav_link_paths
    def group_nav_link_paths
      if ::Gitlab::CurrentSettings.should_check_namespace_plan? && can?(current_user, :admin_group, @group)
        super + %w[billings#index saml_providers#show]
      else
        super
      end
    end

    def size_limit_message_for_group(group)
      show_lfs = group.lfs_enabled? ? 'and their respective LFS files' : ''

      "Repositories within this group #{show_lfs} will be restricted to this maximum size. Can be overridden inside each project. 0 for unlimited. Leave empty to inherit the global value."
    end

    override :group_view_nav_link_active?
    def group_view_nav_link_active?(group_view)
      current_user&.group_view == group_view.to_s &&
        controller.controller_name == 'groups' &&
        controller.action_name == 'show'
    end

    private

    def get_group_sidebar_links
      links = super

      if can?(current_user, :read_group_contribution_analytics, @group) || show_promotions?
        links << :contribution_analytics
      end

      if can?(current_user, :read_epic, @group)
        links << :epics
      end

      if @group.feature_available?(:issues_analytics)
        links << :analytics
      end

      links
    end
  end
end
