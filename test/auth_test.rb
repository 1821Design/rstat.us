require 'require_relative' if RUBY_VERSION[0,3] == '1.8'
require_relative 'test_helper'

class RstatusTest < MiniTest::Unit::TestCase

  include TestHelper

  def test_add_twitter_to_account
    u = Factory(:user)
    OmniAuth.config.add_mock(:twitter, {
      :uid => "78654",
      :user_info => {
        :name => "Joe Public",
        :nickname => u.username,
        :urls => { :Website => "http://rstat.us" },
        :description => "A description",
        :image => "/images/something.png"
      },
      :credentials => {:token => "1111", :secret => "2222"}
    })
    log_in_email(u)
    visit "/users/#{u.username}/edit"
    click_button "Add Twitter Account"

    auth = Authorization.first(:provider => "twitter", :uid => 78654)
    assert_equal "1111", auth.oauth_token
    assert_equal "2222", auth.oauth_secret
    assert_match "/users/#{u.username}/edit", page.current_url
  end

  def test_twitter_remove
    u = Factory(:user)
    a = Factory(:authorization, :user => u)
    log_in(u, a.uid)
  
    visit "/users/#{u.username}/edit"
  
    assert_match /edit/, page.current_url
    click_button "Remove"
  
    a = Authorization.first(:provider => "twitter", :user_id => u.id)
    assert a.nil?
  end

  def test_add_facebook_to_account
    u = Factory(:user)
    OmniAuth.config.add_mock(:facebook, {
      :uid => 78654,
      :user_info => {
        :name => "Joe Public",
        :email => "joe@public.com",
        :nickname => u.username,
        :urls => { :Website => "http://rstat.us" },
        :description => "A description",
        :image => "/images/something.png"
      },
      :credentials => {:token => "1111", :secret => "2222"}
    })
    log_in_email(u)
    visit "/users/#{u.username}/edit"
    click_button "Add Facebook Account"

    auth = Authorization.first(:provider => "facebook", :uid => 78654)
    assert_equal "1111", auth.oauth_token
    assert_equal "2222", auth.oauth_secret
    assert_match "/users/#{u.username}/edit", page.current_url
  end

  def test_facebook_remove
    u = Factory(:user)
    a = Factory(:authorization, :user => u, :provider => "facebook")
    log_in_fb(u, a.uid)
  
    visit "/users/#{u.username}/edit"
  
    assert_match /edit/, page.current_url
    click_button "Remove"
  
    a = Authorization.first(:provider => "facebook", :user_id => u.id)
    assert a.nil?
  end

  def test_user_update_profile_twitter_button
    u = Factory(:user)
    log_in_email(u)
    visit "/users/#{u.username}/edit"

    assert_match page.body, /Add Twitter Account/
  end

  def test_user_update_profile_facebook_button
    u = Factory(:user)
    log_in_email(u)
    visit "/users/#{u.username}/edit"

    assert_match page.body, /Add Facebook Account/
  end

  def test_user_profile_with_twitter
    u = Factory(:user)
    a = Factory(:authorization, :user => u, :nickname => "Awesomeo the Great")
    log_in(u, a.uid)
    visit "/users/#{u.username}/edit"

    assert_match page.body, /Awesomeo the Great/
  end

  def test_user_profile_with_facebook
    u = Factory(:user)
    a = Factory(:authorization, :user => u, :provider => "facebook", :nickname => "Awesomeo the Great")
    log_in_fb(u, a.uid)
    visit "/users/#{u.username}/edit"

    assert_match page.body, /Awesomeo the Great/
  end

  def no_twitter_login
    u = Factory(:user)
    log_in_email(u)
    assert_match /Login successful/, page.body
    assert_equal current_user, u
  end

  def test_twitter_send_checkbox_present
    u = Factory(:user)
    a = Factory(:authorization, :user => u)
    log_in(u, a.uid)

    assert_match page.body, /Twitter/
    assert_equal find_field('tweet').checked?, true
  end

  def test_facebook_send_checkbox_present
    u = Factory(:user)
    a = Factory(:authorization, :user => u, :provider => "facebook")
    log_in_fb(u, a.uid)

    assert_match page.body, /Facebook/
    assert_equal find_field('facebook').checked?, true
  end

  def test_twitter_send
    update_text = "Test Twitter Text"
    Twitter.expects(:update)
    u = Factory(:user)
    a = Factory(:authorization, :user => u)
    log_in(u, a.uid)

    fill_in "text", :with => update_text
    check("tweet")
    click_button "Share"

    assert_match /Update created/, page.body
  end

  def test_facebook_send
    update_text = "Test Facebook Text"
    u = Factory(:user)
    a = Factory(:authorization, :user => u, :provider => "facebook")
    FbGraph::User.expects(:me).returns(mock(:feed! => nil))

    log_in_fb(u, a.uid)

    fill_in "text", :with => update_text
    check("facebook")
    click_button "Share"

    assert_match /Update created/, page.body
  end

  def test_twitter_and_facebook_send
    update_text = "Test Facebook and Twitter Text"
    FbGraph::User.expects(:me).returns(mock(:feed! => nil))    
    Twitter.expects(:update)

    u = Factory(:user)
    Factory(:authorization, :user => u, :provider => "facebook")
    a = Factory(:authorization, :user => u)

    log_in(u, a.uid)
    
    fill_in "text", :with => update_text
    check("facebook")
    check("tweet")
    click_button "Share"

    assert_match /Update created/, page.body
  end

  def test_twitter_no_send
    update_text = "Test Twitter Text"
    Twitter.expects(:update).never
    u = Factory(:user)
    a = Factory(:authorization, :user => u)
    log_in(u, a.uid)

    fill_in "text", :with => update_text
    uncheck("tweet")
    click_button "Share"

    assert_match /Update created/, page.body
  end

  def test_facebook_no_send
    update_text = "Test Facebook Text"
    FbGraph::User.expects(:me).never
    u = Factory(:user)
    a = Factory(:authorization, :user => u, :provider => "facebook")
    log_in_fb(u, a.uid)

    fill_in "text", :with => update_text
    uncheck("facebook")
    click_button "Share"

    assert_match /Update created/, page.body
  end

  def test_no_twitter_no_send
    update_text = "Test Twitter Text"
    Twitter.expects(:update).never
    u = Factory(:user)
    log_in_email(u)
    
    fill_in "text", :with => update_text
    click_button "Share"

    assert_match /Update created/, page.body
  end

  def test_no_facebook_no_send
    update_text = "Test Facebook Text"
    FbGraph::User.expects(:me).never
    u = Factory(:user)
    log_in_email(u)
    
    fill_in "text", :with => update_text
    click_button "Share"

    assert_match /Update created/, page.body
  end

  def test_facebook_username
    new_user = Factory.build(:user, :username => 'profile.php?id=12345')
    log_in_fb(new_user)
    assert_match /users\/new/, page.current_url, "not on the new user page."

    fill_in "username", :with => "janepublic"
    click_button "Finish Signup"
    assert_match /Thanks! You're all signed up with janepublic for your username./, page.body
    assert_match /\//, page.current_url
    click_link "Logout"
    log_in_fb(new_user)
    assert_match /janepublic/, page.body
  end

  def test_existing_profile_php_rename_user
    existing_user = Factory(:user, :username => 'profile.php?id=12345')
    a = Factory(:authorization, :user => existing_user)
    log_in(existing_user, a.uid)
    click_link "reset_username"
    assert_match /\/reset-username/, page.current_url
    fill_in "username", :with => "janepublic"
    click_button "Update"
    assert_match /janepublic/, page.body
  end

  def test_user_signup_twitter
    Author.any_instance.stubs(:valid_gravatar?).returns(:false)
    omni_mock("twit")
    visit '/auth/twitter'

    assert_match /Confirm account information/, page.body
    assert_match /\/users\/confirm/, page.current_url

    fill_in "username", :with => "new_user"
    fill_in "email", :with => "new_user@email.com"
    click_button "Finish Signup"

    u = User.first(:username => "new_user")
    refute u.nil?
    assert_equal u.email, "new_user@email.com"

  end

  def test_user_token_migration
    u = Factory(:user)
    a = Factory(:authorization, :user => u, :oauth_token => nil, :oauth_secret => nil, :nickname => nil)
    log_in(u, a.uid)
  
    assert_equal "1234", u.twitter.oauth_token
    assert_equal "4567", u.twitter.oauth_secret
    assert_equal u.username, u.twitter.nickname
  end

end
