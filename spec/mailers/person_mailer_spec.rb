require 'spec_helper'

describe PersonMailer, type: :mailer do

  # Include EmailSpec stuff (https://github.com/bmabey/email-spec)
  include(EmailSpec::Helpers)
  include(EmailSpec::Matchers)

  before(:each) do
    @test_person = FactoryBot.create(:person)
    @test_person2 = FactoryBot.create(:person)
    @test_person2.locale = "en"
    @test_person2.save
    @community = FactoryBot.create(:community)
  end

  it "should send email about a new message" do
    @conversation = FactoryBot.create(:conversation)
    @conversation.participants = [@test_person2, @test_person]
    @message = FactoryBot.create(:message)
    @message.conversation = @conversation
    @message.save
    email = MailCarrier.deliver_now(PersonMailer.new_message_notification(@message, @community))
    assert !ActionMailer::Base.deliveries.empty?
    assert_equal @test_person2.confirmed_notification_email_addresses, email.to
    assert_equal "You have a new message from #{PersonViewUtils.person_display_name_for_type(@message.sender, 'first_name_with_initial')} in Sharetribe", email.subject
  end

  it "should send email about a new comment to own listing" do
    @comment = FactoryBot.create(:comment)
    @comment.author.update({ "given_name" => "Teppo", "family_name" => "Testaaja" })
    recipient = @comment.listing.author
    email = MailCarrier.deliver_now(PersonMailer.new_comment_to_own_listing_notification(@comment, @community))
    assert !ActionMailer::Base.deliveries.empty?
    assert_equal recipient.confirmed_notification_email_addresses, email.to
    assert_equal "Teppo T has commented on your listing in Sharetribe", email.subject
  end

  it "should send email about listing with payment but without user's payment details" do
    community = FactoryBot.create(:community)
    listing = FactoryBot.create(:listing, listing_shape_id: 123)

    TransactionService::API::API.settings.provision(
      community_id: community.id,
      payment_gateway: :paypal,
      payment_process: :preauthorize,
      active: true)

    recipient = listing.author
    email = MailCarrier.deliver_now(PersonMailer.payment_settings_reminder(listing, recipient, community))

    assert !ActionMailer::Base.deliveries.empty?
    assert_equal recipient.confirmed_notification_email_addresses, email.to
    assert_equal "Remember to add your payment details to receive payments", email.subject
  end

  describe "status changed" do

    let(:author) { FactoryBot.build(:person) }
    let(:listing) { FactoryBot.build(:listing, author: author, listing_shape_id: 123) }
    let(:starter) { FactoryBot.build(:person, given_name: "Teppo", family_name: "Testaaja") }
    let(:conversation) { FactoryBot.build(:conversation) }
    let(:transaction) { FactoryBot.create(:transaction, listing: listing, starter: starter, conversation: conversation) }
    let(:community) { FactoryBot.create(:community) }

    before(:each) do
      conversation.messages.build({
        sender: starter,
        content: "Test"
      })
    end

    it "should send email about an accepted offer or request" do
      transaction.transaction_transitions = [FactoryBot.create(:transaction_transition, to_state: "accepted")]
      transaction.current_state = "accepted"
      transaction.save!
      transaction.reload
      email = MailCarrier.deliver_now(PersonMailer.conversation_status_changed(transaction, community))
      assert !ActionMailer::Base.deliveries.empty?
      assert_equal starter.confirmed_notification_email_addresses, email.to
      assert_equal "Your request was accepted", email.subject
    end

    it "should send email about a rejected offer or request" do
      transaction.transaction_transitions = [FactoryBot.create(:transaction_transition, to_state: "rejected")]
      transaction.current_state = "rejected"
      transaction.save!
      transaction.reload
      email = MailCarrier.deliver_now(PersonMailer.conversation_status_changed(transaction, community))
      assert !ActionMailer::Base.deliveries.empty?
      assert_equal starter.confirmed_notification_email_addresses, email.to
      assert_equal "Your request was rejected", email.subject
    end

  end

  it "should send email about a new testimonial" do
    @test_person.update({ "given_name" => "Teppo", "family_name" => "Testaaja" })

    transition = FactoryBot.build(:transaction_transition, to_state: "confirmed")
    listing = FactoryBot.build(:listing,
                                transaction_process_id: 123, # not needed, but mandatory
                                listing_shape_id: 123, # not needed, but mandatory
                                author: @test_person)
    transaction = FactoryBot.create(:transaction, starter: @test_person2, listing: listing, transaction_transitions: [transition])
    testimonial = FactoryBot.create(:testimonial, grade: 0.75, text: "Yeah", author: @test_person, receiver: @test_person2, tx: transaction)

    email = MailCarrier.deliver_now(PersonMailer.new_testimonial(testimonial, @community))
    assert !ActionMailer::Base.deliveries.empty?
    assert_equal @test_person2.confirmed_notification_email_addresses, email.to
    assert_equal "Teppo T has given you feedback in Sharetribe", email.subject
  end

  it "should remind about testimonial" do
    author = FactoryBot.build(:person)
    starter = FactoryBot.build(:person, given_name: "Teppo", family_name: "Testaaja")
    listing = FactoryBot.build(:listing, author: author, listing_shape_id: 123)
    # Create is needed here, not exactly sure why
    conversation = FactoryBot.create(:transaction, starter: starter, listing: listing)

    email = MailCarrier.deliver_now(PersonMailer.testimonial_reminder(conversation, author, @community))
    assert !ActionMailer::Base.deliveries.empty?
    assert_equal author.confirmed_notification_email_addresses, email.to
    assert_equal "Reminder: remember to give feedback to Teppo T", email.subject
  end

  it "should send email to admins of new feedback" do
    @feedback = FactoryBot.create(:feedback)
    @community = FactoryBot.create(:community)
    email = MailCarrier.deliver_now(PersonMailer.new_feedback(@feedback, @community))
    assert !ActionMailer::Base.deliveries.empty?
    assert_equal APP_CONFIG.feedback_mailer_recipients.split(", "), email.to
  end

  it "should send email to community admins of new feedback if that setting is on" do
    @feedback = FactoryBot.create(:feedback)
    @community = FactoryBot.create(:community)
    m = CommunityMembership.create(:person_id => @test_person.id, :community_id => @community.id, :status => "accepted")
    m.update_attribute(:admin, true)
    email = MailCarrier.deliver_now(PersonMailer.new_feedback(@feedback, @community))
    assert !ActionMailer::Base.deliveries.empty?
    assert_equal @test_person.confirmed_notification_email_addresses, email.to
  end

  it "should send email to community admins of new member if wanted" do
    @community = FactoryBot.create(:community, :email_admins_about_new_members => 1)
    m = CommunityMembership.create(:person_id => @test_person.id, :community_id => @community.id, :status => "accepted")
    m.update_attribute(:admin, true)
    email = MailCarrier.deliver_now(PersonMailer.new_member_notification(@test_person2, @community, @community.admins.first))
    assert !ActionMailer::Base.deliveries.empty?
    assert_equal @test_person.confirmed_notification_email_addresses, email.to
    assert_equal "New member in #{@community.full_name('en')}", email.subject
  end

  describe "#welcome_email" do

    before(:each) do
      @c1 = FactoryBot.create(:community)
      @p1 = FactoryBot.create(:person, :emails => [FactoryBot.create(:email, :address => "update_tester@example.com")])

      @p1.accepted_community = @c1
    end

    it "should welcome a regular member" do
      @email = PersonMailer.welcome_email(@p1, @p1.accepted_community)
      expect(@email).to deliver_to("update_tester@example.com")
      expect(@email).to have_subject("Welcome to Sharetribe")
      expect(@email).to have_body_text "Welcome to Sharetribe! Glad to have you on board."
      expect(@email).not_to have_body_text "You have now admin rights in this community."
    end

    it "should contain custom content if that is defined for the community" do
      @c1.community_customizations.first.update_attribute(:welcome_email_content, "Custom email")
      @email = PersonMailer.welcome_email(@p1, @p1.accepted_community)
      expect(@email).to have_body_text "Custom email"
      expect(@email).not_to have_body_text "Add something you could offer to others."
      expect(@email).not_to have_body_text "You have now admin rights in this community."
    end

  end

  describe "#new_listing_by_followed_person" do

    before do
      @community = FactoryBot.create(:community)
      @listing = FactoryBot.create(:listing, listing_shape_id: 123, community_id: @community.id)
      @recipient = FactoryBot.create(:person)
    end

    it "should notify of a new listing" do
      email = MailCarrier.deliver_now(PersonMailer.new_listing_by_followed_person(@listing, @recipient, @community))
      assert !ActionMailer::Base.deliveries.empty?
      assert_equal @recipient.confirmed_notification_email_addresses, email.to
    end

  end

  describe "#community_member_email_from_admin" do
    let(:community) { FactoryBot.create(:community) }
    let(:sender) { FactoryBot.create(:person, member_of: community, member_is_admin: true) }
    let(:recipient) { FactoryBot.create(:person, member_of: community) }

    it 'works ordinary user as recipient' do
      content = 'Have nice day!'
      email = PersonMailer.community_member_email_from_admin(sender, recipient, community, content, 'any')
      expect(email).to have_subject("A new message from the #{community.name('en')} team")
      expect(email).to have_body_text("Hello #{PersonViewUtils.person_display_name_for_type(recipient, 'first_name_only')},")
      expect(email).to have_body_text('Have nice day!')
    end

    it 'works yourself as recipient' do
      content = 'Have nice day!'
      email = PersonMailer.community_member_email_from_admin(sender, sender, community, content, 'any')
      expect(email).to have_subject("A new message from the #{community.name('en')} team")
      expect(email).to have_body_text("Hello #{PersonViewUtils.person_display_name_for_type(sender, 'first_name_only')},")
      expect(email).to have_body_text('Have nice day!')
    end
  end

  describe "#transaction_confirmed" do
    let(:community) { FactoryBot.create(:community) }
    let(:seller) {
      FactoryBot.create(:person, member_of: community,
                                 given_name: "Joan", family_name: "Smith")
    }
    let(:buyer) { FactoryBot.create(:person, member_of: community) }
    let(:listing) { FactoryBot.create(:listing, community_id: community.id, author: seller) }
    let(:confirmed_transaction) {
      FactoryBot.create(:transaction, starter: buyer,
                                      community: community, listing: listing,
                                      current_state: 'confirmed')
    }

    it 'works with default payment gateway' do
      email = PersonMailer.transaction_confirmed(confirmed_transaction, community)
      expect(email.body).to have_text("Proto T has marked the order about Sledgehammer completed.")
      expect(email.body).to have_text("You can now give feedback to Proto T.")
    end

    it 'works with stripe payment gateway' do
      confirmed_transaction.update_column(:payment_gateway, 'stripe')
      confirmed_transaction.reload
      email = PersonMailer.transaction_confirmed(confirmed_transaction, community)
      expect(email.body).to have_text("Proto T has marked the order about Sledgehammer completed.")
      expect(email.body).to have_text("The payment for this transaction has now been released to your bank account.")
      expect(email.body).to have_text("You can now give feedback to Proto T.")
    end
  end

  describe "#new_ident_notification" do
    it 'change ident email' do
      @community.ident = 'ident'

      @person = Person.first
      email = MailCarrier.deliver_now(PersonMailer.new_ident_notification(@community, @person, @community.ident, 'new_ident'))
      assert !ActionMailer::Base.deliveries.empty?
      assert_equal @person.confirmed_notification_email_addresses, email.to
      assert_equal "Your marketplace address was changed", email.subject
      expect(email).to have_body_text('new_ident')
    end
  end
end
