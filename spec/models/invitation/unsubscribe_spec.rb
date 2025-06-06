# == Schema Information
#
# Table name: invitation_unsubscribes
#
#  id           :bigint           not null, primary key
#  community_id :integer
#  email        :string(255)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_invitation_unsubscribes_on_community_id  (community_id)
#  index_invitation_unsubscribes_on_email         (email)
#

require 'spec_helper'

RSpec.describe Unsubscribe, type: :model do
  let(:invitation) { FactoryBot.create(:invitation, code: 'ABC', email: 'cindy@example.com') }
  let(:invitation_unsubscribe) { FactoryBot.create(:invitation_unsubscribe) }
  let(:community) { FactoryBot.create(:community) }

  context '#unsubscribe' do
    it 'creates unsubscribe record' do
      expect(Unsubscribe.count).to eq 0
      Unsubscribe.unsubscribe(invitation.code)
      expect(Unsubscribe.count).to eq 1
    end
  end

  context '#remove_unsubscribed_emails' do
    it 'works' do
      invitation_unsubscribe
      invitation_emails = ['sherry@example.com', 'thelma@example.com']
      result = Unsubscribe.remove_unsubscribed_emails(invitation_unsubscribe.community, invitation_emails)
      expect(result).to eq ['thelma@example.com']
    end

    it 'does not remove email related to another community' do
      invitation_unsubscribe
      invitation_emails = ['sherry@example.com', 'thelma@example.com']
      result = Unsubscribe.remove_unsubscribed_emails(community, invitation_emails)
      expect(result).to eq ['sherry@example.com', 'thelma@example.com']
    end
  end
end
