require 'open-uri'
require 'octokit'
require 'json'
require 'benchmark'

class BobStatus
  def initialize
    @repo = 'revdotcom/revdotcom'
    @jenkins_auth = auth = {:http_basic_authentication => ['vladimir', ENV['JENKINS_ACCESS_TOKEN']]}
    @client = Octokit::Client.new(:access_token => ENV['GITHUB_ACCESS_TOKEN'])
    @feature_branch_view_url = "https://ci.rev.com:8443/view/Rev.com%20Feature%20Branch%20Builds/api/json"
    @requests_to_jenkins = 0
    @cache = Cache.new
  end

  def post_status(commit)
    return
    @client.create_status(@repo, commit[:sha], commit[:status], {
      :target_url => commit[:target_url],
      :context => 'Bobs status'
    })
  end

  def is_my_commit(sha)
    commit = @client.commit(@repo, sha)
    commit[:commit][:author][:name] == "Vladimir Penkin"
  end

  def jget(url)
    @requests_to_jenkins += 1
    url += 'api/json' if url[-8..-1] != 'api/json'
    JSON.parse(open(url, @jenkins_auth).read)
  end

  def feature_branch_views
    feature_branch_views = jget(@feature_branch_view_url)
    feature_branch_views['views'].select{|v|
      v['name'].match /FOX/
    }
  end

  def build_jobs
    feature_branch_views.collect{|v|
      feature_branch_view = jget(v['url'])
      feature_branch_view['jobs'].select{|job|
        job['name'].match "build-feature"
      }
    }.flatten
  end

  def builds
    build_jobs.collect{|build_job|
      job = jget(build_job['url'])
      job['builds'].first # first build is recent
    }
  end

  def statuses
    builds.collect{|b|
      build = jget(b['url'])
      actions = build['actions'].find{|action|
        action.has_key? "buildsByBranchName"
      }['buildsByBranchName']

      build_action = actions.values.first
      build_id = build_action['buildNumber']
      sha = build_action['marked']['SHA1']

      status = 'pending'
      if build['building'] == false
        status = build['result'].downcase
      end

      build['url'] += 'console' unless status == 'failure' # link to error log if failed

      {:sha => sha,
       :status => status,
       :target_url => build['url'],
       :build_id => build_id,
       :created_at => Time.now
     }
    }
  end

  def commits
    statuses.select{|status|
      is_my_commit(status[:sha])
    }
  end

  def run
    posted = []
    commits.each{|commit|
      unless @cache.posted?(commit[:sha], commit[:status])
        @cache.add_or_update(commit)
        post_status(commit)
        posted << commit
      end
    }
    @cache.save

    puts "Requests to Jenkins made: #{@requests_to_jenkins}"
    puts "Statuses posted: #{posted}"
  end
end

# github status api has 1000 limit per sha.
# we need to cache statuses that we already posted and do not repost them

class Cache
  attr_accessor :cache

  def initialize
    @file = open('cache.js', 'r')
    contents = @file.read
    @cache = JSON.parse(contents)['data'] || []
  end

  def add_or_update(commit)
    @cache.reject!{|cc|
      cc['sha'] == commit[:sha]
    }
    @cache << commit
  end

  def exist(sha)
    @cache.find{|commit|
      commit['sha'] == sha
    }
  end

  def posted?(sha, status)
    commit = exist(sha)
    commit && commit['status'] == status
  end

  def save
    @file.close
    @file = open('cache.js', 'w')
    @file.write({:data => @cache}.to_json)
    @file.close
  end
end

puts Benchmark.measure {
  BobStatus.new.run
}
