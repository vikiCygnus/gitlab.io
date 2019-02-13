# frozen_string_literal: true

shared_examples 'ensures security dashboard permissions' do
  let(:http_status_when_security_dashboard_disabled) { 404 }

  context 'when security dashboard feature is enabled' do
    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'and user is allowed to access group security dashboard' do
      before do
        group.add_developer(user)
      end

      it { is_expected.to have_gitlab_http_status(200) }
    end

    context 'when user is not allowed to access group security dashboard' do
      it { is_expected.to have_gitlab_http_status(200) } # still renders the response but with different contents
    end
  end

  context 'when security dashboard feature is disabled' do
    it { is_expected.to have_gitlab_http_status(http_status_when_security_dashboard_disabled) }
  end
end
