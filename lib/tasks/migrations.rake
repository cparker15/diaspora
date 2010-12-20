#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require File.join(Rails.root, 'lib/rake_helpers')
include RakeHelpers

namespace :migrations do

  desc 'make old registered services into the new class specific services'
  task :service_reclassify do
    require File.join(Rails.root,"config/environment")
    Service.all.each do |s|
      provider = s.provider
      if provider
        s._type = "Services::#{provider.camelize}"
        s.save
      else
        puts "no provider found for service #{s.id}"
      end
    end
    puts "all done"
  end

  desc 'fix people with spaces in their diaspora handles'
  task :fix_space_in_diaspora_handles do
    RakeHelpers::fix_diaspora_handle_spaces(false)
  end

  task :contacts_as_requests do
    require File.join(Rails.root,"config/environment")
    puts "Migrating contacts..."
    MongoMapper.database.eval('
      db.contacts.find({pending : null}).forEach(function(contact){
        db.contacts.update({"_id" : contact["_id"]}, {"$set" : {"pending" : false}}); });')
    puts "Deleting stale requests..."
    Request.find_each(:sent => true){|request|
      request.delete
    }
    puts "Done!"
  end

  desc 'fix usernames with periods in them'
  task :fix_periods_in_username do
    RakeHelpers::fix_periods_in_usernames(false)
  end

  desc 'purge broken contacts'
  task :purge_broken_contacts do
  end

  desc 'absolutify all existing image references'
  task :absolutify_image_references do
    require File.join(Rails.root,"config/environment")

    Photo.all.each do |photo|
      unless photo.remote_photo_path
        # extract root
        pod_url = photo.person.url
        pod_url.chop! if pod_url[-1,1] == '/'

        if photo.image.url
          remote_path = "#{pod_url}#{photo.image.url}"
        else
          remote_path = "#{pod_url}#{photo.remote_photo_path}/#{photo.remote_photo_name}"
        end

        # get path/filename
        name_start = remote_path.rindex '/'
        photo.remote_photo_path = "#{remote_path.slice(0, name_start)}/"
        photo.remote_photo_name = remote_path.slice(name_start + 1, remote_path.length)

        photo.save!
      end
    end
  end
end
