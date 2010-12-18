#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require 'spec_helper'
require File.join(Rails.root, 'lib/hcard')
require "rake"

describe 'migrations' do
  describe 'service_reclassify' do
    it 'makes classless servcices have class' do
      s1 = Service.new(:access_token => "foo", :access_secret => "barbar", :provider => "facebook")
      s2 = Service.new(:access_token => "foo", :access_secret => "barbar", :provider => "twitter")
      s1.save
      s2.save

      @rake = Rake::Application.new
      Rake.application = @rake
      Rake.application.rake_require "lib/tasks/migrations", [Rails.root]
      Rake::Task.define_task(:environment) {}
      silence_stream(STDOUT) do
        silence_warnings { @rake['migrations:service_reclassify'].invoke }
      end

      Service.all.any?{|x| x.class.name == "Services::Twitter"}.should be true
      Service.all.any?{|x| x.class.name == "Services::Facebook"}.should be true
    end
  end

  describe 'absolutify_image_references' do
    before do
      @rake = Rake::Application.new
      Rake.application = @rake
      Rake.application.rake_require "lib/tasks/migrations", [Rails.root]
      Rake::Task.define_task(:environment) {}

      @fixture_filename  = 'button.png'
      @fixture_name      = File.join(File.dirname(__FILE__), '..', '..', 'fixtures', @fixture_filename)

      @photos = []

      5.times do |n|
        photo = Photo.instantiate(:user_file => File.open(@fixture_name))
        photo.remote_photo_path = nil
        photo.remote_photo_name = nil

        photo.person = (n % 2 == 0 ? make_user.person : Factory(:person, :url => "https://remote.com/"))
        @photos[n] = photo
        @photos[n].save
      end
    end

    it 'sets remote_photo_path and remote_photo_name' do
      @rake['migrations:absolutify_image_references'].invoke

      @photos.each do |photo|
        photo.reload

        photo.remote_photo_path.should be_true
        photo.remote_photo_name.should be_true
        photo.url.match(/$http.*jpg^/)
      end

      @photos[0].remote_photo_path.should include("http://google-")
      @photos[1].remote_photo_path.should include("https://remote.com/")
    end
  end
end

