require "rubygems"
require "google_drive"
require 'box-api'
require 'launchy'

# Read config file
app_data_file = File.expand_path(File.dirname(__FILE__)) + '/app_data.yml'
app_data = YAML.load_file(app_data_file)


# Logs in.
# You can also use OAuth. See document of
# GoogleDrive.login_with_oauth for details.
session = GoogleDrive.login(app_data['google_user'], app_data['google_pass'])

# First worksheet of test spreadsheet file
ws = session.spreadsheet_by_title('test').worksheets[0]

a = []

# Search for row of ncopy
for row in 2..ws.num_rows
  if ws[row,2] == 'ncopy'
    a.push(ws[row,1])
     ws[row,2] = 'moved'
  end
end
ws.save()

# create an account object using the API key stored in app_data.yml
# you need to get your own API key at http://www.box.net/developers/services
account = Box::Account.new(app_data['api_key'])

# read any auth tokens if they are saved, so we don't have to re-authenticate on Box
auth_token = app_data['auth_token']

# try to authorize using the auth token, or request a new one if not
account.authorize(:auth_token => auth_token) do |auth_url|
  # this block is called if the auth_token is invalid or missing
  # we use launchy to open a new browser to the given url
  Launchy.open(auth_url)

  # wait until the user authenticates on box before continuing
  puts "Please press the enter key once you have authorized this application to use your account"
  gets
end

unless account.authorized?
  # the user didn't authorize like we told them to, so we can't access anything
  puts "Unable to login, please try again."
  exit
end

# we managed to log in successfully!
puts "Logged in as #{ account.login }"


# this auth token will let us instantly authorize next time this app is run, so we save it
app_data['auth_token'] = account.auth_token

File.open(app_data_file, 'w') do |file|
  YAML.dump(app_data, file)
end

root = account.root

# find index of folder_test
folder = root.folders.select{|x| x.name == "folder_test"}.first
dest = root.folders.select{|x| x.name == "folder_test_mod"}.first

files = folder.files.map{|x| x.name }
file_names = files.map{|x| x.split(".").first }
folder_files = folder.files

# loop through and show each of the sub files and folders
file_names.each_with_index do |file, i|
  if a.include?(file)
    puts "#{ file } is in folder, moving to folder_test_mod"
    folder_files[i].move(dest)
  end
end

