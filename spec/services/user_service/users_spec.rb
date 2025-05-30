require 'spec_helper'

describe UserService::API::Users do

  include UserService::API::Users

  include EmailSpec::Helpers
  include EmailSpec::Matchers

  PERSON_HASH = {
    given_name: "Raymond",
    family_name: "Xperiment",
    email: "Ray@example.com",
    password: "test",
    locale: "fr"
  }

  describe "#create_user" do

    before { ActionMailer::Base.deliveries = [] }

    before(:each) do
      expect(ActionMailer::Base.deliveries).to be_empty
      @community = FactoryBot.create(:community)
    end

    it "should create a user" do
      c = FactoryBot.create(:community)
      u = create_user(PERSON_HASH, c.id).data
      expect(u[:given_name]).to eql "Raymond"
      expect(Person.find_by(username: "raymondx").family_name).to eql "Xperiment"
      expect(u[:locale]).to eql "fr"
    end

    it "should fail if email is taken" do
      c = FactoryBot.create(:community)
      create_user(PERSON_HASH, c.id)
      expect{create_user(PERSON_HASH, c.id)}.to raise_error(ArgumentError, /Email Ray@example.com is already in use/)
    end

    it "should send the confirmation email" do
      create_user(PERSON_HASH.merge({:locale => "en"}), @community.id)

      process_jobs

      expect(ActionMailer::Base.deliveries).not_to be_empty

      email = ActionMailer::Base.deliveries.first
      expect(email).to have_subject I18n.t("devise.mailer.confirmation_instructions.subject",
                                           service_name: ApplicationHelper.fetch_community_service_name_from_thread)
      # simple check that link to right community exists
      email_body = email.html_part.body.to_s
      expect(email_body).to match @community.full_domain
      expect(email_body).to match "Confirm email address"
    end

    it "should send the confirmation email in right language" do
      create_user(PERSON_HASH.merge({:locale => "fr"}), @community.id)

      process_jobs

      expect(ActionMailer::Base.deliveries).not_to be_empty

      email = ActionMailer::Base.deliveries.first
      expect(email).to have_subject I18n.t("devise.mailer.confirmation_instructions.subject",
                                           locale: "fr",
                                           service_name: ApplicationHelper.fetch_community_service_name_from_thread)
    end
  end

  describe "#delete_user" do
    let(:user) { FactoryBot.create(:person) }
    let!(:membership) { FactoryBot.create(:community_membership, person: user) }
    let!(:auth_token) { FactoryBot.create(:auth_token, person: user) }
    let!(:follower) { FactoryBot.create(:person) }
    let!(:followed) { FactoryBot.create(:person) }
    let!(:follower_relationship) { FactoryBot.create(:follower_relationship, person: user, follower: follower) }
    let!(:followed_relationship) { FactoryBot.create(:follower_relationship, person: followed, follower: user) }

    it "removes user data and adds deleted flag" do
      new_user = Person.find(user.id)

      expect(new_user.given_name).not_to be_nil
      expect(new_user.family_name).not_to be_nil
      expect(new_user.emails).not_to be_empty
      expect(new_user.community_membership).not_to be_nil
      expect(new_user.auth_tokens).not_to be_nil
      expect(new_user.follower_relationships.length).to eql(1)
      expect(new_user.inverse_follower_relationships.length).to eql(1)

      # flag
      expect(new_user.deleted).not_to eql(true)

      Person.delete_user(user.id)

      deleted_user = Person.find(user.id)
      expect(deleted_user.given_name).to be_nil
      expect(deleted_user.family_name).to be_nil
      expect(deleted_user.emails).to be_empty
      expect(deleted_user.community_membership.status).to eq("deleted_user")
      expect(deleted_user.auth_tokens).to be_empty
      expect(deleted_user.follower_relationships.length).to eql(0)
      expect(deleted_user.inverse_follower_relationships.length).to eql(0)

      expect(deleted_user.deleted).to eql(true)
    end
  end

end
