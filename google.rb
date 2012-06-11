# hello.rb
require "nancy"
require "google_drive"
require 'box-api'

class Google < Nancy::Base
  use Rack::Session::Cookie # for sessions
  include Nancy::Render # for templates

  get "/" do
    if params['auth_token']
      @message = "You've logged successfully, please press SEND again"
      session['auth_token'] = params['auth_token']
    end
    render "views/index.erb"
  end

  post "/" do
    app_data_file = File.expand_path(File.dirname(__FILE__)) + '/app_data.yml'
    app_data = YAML.load_file(app_data_file)
    g_session = GoogleDrive.login(app_data['google_user'], app_data['google_pass'])

    account = Box::Account.new(app_data['api_key'])

    auth_token = app_data['auth_token'] || session['auth_token']

    account.authorize(:auth_token => auth_token) do |auth_url|
      redirect auth_url
    end

    halt 400, "Unable to login" unless account.authorized?
    
    ws = g_session.spreadsheet_by_title('test').worksheets[0]
    a = []
    for row in 2..ws.num_rows
      if ws[row,2] == 'ncopy'
        a.push(ws[row,1])
        ws[row,2] = 'moved'
      end
    end
    ws.save
    
    root = account.root
    folder = root.folders.select{|x| x.name == "folder_test"}.first
    dest = root.folders.select{|x| x.name == "folder_test_mod"}.first

    files = folder.files.map{|x| x.name }
    file_names = files.map{|x| x.split(".").first }
    folder_files = folder.files

    file_names.each_with_index do |file, i|
      if a.include?(file)
        folder_files[i].move(dest)
      end
    end
     
    @message = "Done"
    render "views/index.erb"
  end
end

