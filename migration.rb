require 'rubygems'
require "net/http"
require "uri"
require "json"
require 'octokit'
require 'date'
require 'pp'
require 'pry'

# JIRA STUFF
USERNAME = ''
PASSWORD = ''
HOST = 'ABC.atlassian.net'
PORT = '443'
ISSUE_ENDPOINT = '/rest/api/2/issue'
COMMENT_ENDPOINT = "/rest/api/2/issue/IDKEY/comment"
PROJECT_ID = 10000

# GITHUB STUFF
GITHUB_USER = ''
GITHUB_PASS = ''
GITHUB_PROJECTUSER = ''
GITHUB_PROJECT = ''

def post(payload, endpoint)
    req = Net::HTTP::Post.new(endpoint, initheader = {'Content-Type' =>'application/json'})
    req.basic_auth USERNAME, PASSWORD
    req.body = payload
    socket = Net::HTTP.new(HOST, PORT)
    socket.use_ssl = true
    response = socket.start {|http| http.request(req) }
    response.body
end

TIMEZONE_OFFSET="-5"

client = Octokit::Client.new(:login => GITHUB_USER, :password => GITHUB_PASS)

issues = []
temp_issues = []
page = 0

begin
	page = page +1
	temp_issues = client.list_issues("#{GITHUB_PROJECTUSER}/#{GITHUB_PROJECT}", :state => "closed", :page => page)
	issues = issues + temp_issues;
end while not temp_issues.empty?

temp_issues = []
page = 0
begin
	page = page +1
	temp_issues = client.list_issues("#{GITHUB_PROJECTUSER}/#{GITHUB_PROJECT}", :state => "open", :page => page)
	issues = issues + temp_issues;
end while not temp_issues.empty?

issues.each_with_index do |i, index| 
    issue_summary = " ["+ i['number'].to_s + "] " + i['title']
    if i['state'] == 'open' 
        issue_summary = " ["+ i['number'].to_s + "] " + i['title']
    else 
        begin 
            issue_summary = "[CLOSE] ["+ i['number'].to_s + "] "+ i['title']
        rescue
            binding.pry 
        end
    end
    request =  {
        :fields =>  { 
        :project => {:id => PROJECT_ID}, 
        :summary => issue_summary,
        :reporter => {:name => USERNAME},
        :description => i['body'],
        :labels => i['labels'].collect { |l| l['name'] },
        :issuetype => {:id => 1},
        :assignee => {:name => USERNAME}
    } 
    } 

    begin
        resp = JSON.parse(post(request.to_json, ISSUE_ENDPOINT))
        issue_id = resp['id']

        issue_comments = client.issue_comments("#{GITHUB_PROJECTUSER}/#{GITHUB_PROJECT}", i['number']).collect {|ic| ic['body'] }
        issue_comments.each do |c|
            request = { 
                :body => c
            }
            post(request.to_json, COMMENT_ENDPOINT.gsub('IDKEY', issue_id))
        end
    rescue 
        p "Error processing: #{request}"
    end

    p "#{index}/#{issues.size} + #{issue_comments.size} comments"
end
