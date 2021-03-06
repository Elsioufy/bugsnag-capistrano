require 'webmock/rspec'
require 'rspec/expectations'
require 'rspec/mocks'

require 'webrick'

describe "bugsnag capistrano" do

  server = nil
  queue = Queue.new
  cap_2 = ENV['CAP_2_TEST'] == 'true'
  fixture_path = cap_2 ? '../examples/capistrano2' : '../examples/capistrano3'
  exec_string = cap_2 ? 'bundle exec cap deploy' : 'bundle exec cap test deploy'
  example_path = File.join(File.dirname(__FILE__), fixture_path)

  before do
    server = WEBrick::HTTPServer.new :Port => 0, :Logger => WEBrick::Log.new(STDOUT), :AccessLog => []
    server.mount_proc '/deploy' do |req, res|
      queue.push req.body
      res.status = 200
      res.body = "OK\n"
    end
    Thread.new{ server.start }
  end

  after do
    server.stop
    queue.clear
  end

  let(:request) { JSON.parse(queue.pop) }

  it "sends a deploy notification to the set endpoint" do
    ENV['BUGSNAG_ENDPOINT'] = "http://localhost:" + server.config[:Port].to_s + "/deploy"
    ENV['BUGSNAG_APP_VERSION'] = "1"

    Dir.chdir(example_path) do
      system(exec_string)
    end

    payload = request()
    expect(payload["apiKey"]).to eq('YOUR_API_KEY')
    expect(payload["appVersion"]).to eq("1")
    expect(payload["releaseStage"]).to eq('production')
  end

  it "allows modifications of deployment characteristics" do
    ENV['BUGSNAG_ENDPOINT'] = "http://localhost:" + server.config[:Port].to_s + "/deploy"
    ENV['BUGSNAG_API_KEY'] = "this is a test key"
    ENV['BUGSNAG_RELEASE_STAGE'] = "test"
    ENV['BUGSNAG_REVISION'] = "test"
    ENV['BUGSNAG_APP_VERSION'] = "1"
    ENV['BUGSNAG_REPOSITORY'] = "test@repo.com:test/test_repo.git"
    ENV['BUGSNAG_SOURCE_CONTROL_PROVIDER'] = "github"
    ENV['BUGSNAG_AUTO_ASSIGN_RELEASE'] = 'true'

    Dir.chdir(example_path) do
      system(exec_string)
    end

    payload = request()
    expect(payload["apiKey"]).to eq('this is a test key')
    expect(payload["releaseStage"]).to eq('test')
    expect(payload["appVersion"]).to eq("1")
    expect(payload["sourceControl"]).to_not be_nil
    expect(payload["sourceControl"]["revision"]).to eq("test")
    expect(payload["sourceControl"]["repository"]).to eq("test@repo.com:test/test_repo.git")
    expect(payload["sourceControl"]["provider"]).to eq("github")
    expect(payload["autoAssignRelease"]).to eq(true)
  end
end

