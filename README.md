[![Gem Downloads](http://img.shields.io/gem/dt/capistrano3-asg-ami.svg)](https://rubygems.org/gems/capistrano3-asg-ami) [![Gem Version](https://badge.fury.io/rb/capistrano3-asg-ami.png)](http://badge.fury.io/rb/capistrano3-asg-ami) [![MIT license](http://img.shields.io/badge/license-MIT-brightgreen.svg)](http://opensource.org/licenses/MIT)
# capistrano3-asg-ami
Capistrano 3 plugin for updating AWS [Launch Template](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-launch-templates.html) [AMI](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) with [autoscale group](https://aws.amazon.com/about-aws/whats-new/2018/01/introducing-aws-auto-scaling/) first healthy instance.

## Requirements

* aws-sdk-ec2 ~> 1
* aws-sdk-autoscaling ~> 1
* capistrano ~> 3


## Installation

Add this line to your application's Gemfile:

    gem 'capistrano3-asg-ami'

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install capistrano3-asg-ami

Add this line to your application's Capfile:

```ruby
require 'capistrano/autoscaling'
```

## Usage

Create [IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html) with [AmazonEC2FullAccess](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_examples_ec2_region.html) permission and Set credentials in the capistrano deploy script / stage files add the following lines

```ruby
set :aws_region, 'ap-northeast-1'
set :aws_access_key_id, 'YOUR AWS KEY ID'
set :aws_secret_access_key, 'YOUR AWS SECRET KEY'
set :aws_autoscaling_group_name, 'YOUR NAME OF AUTO SCALING GROUP NAME'
set :aws_launch_template_id, 'Your AUTOSCALE GROUP Launch template ID'
set :aws_autoscale_ami_prefix, 'server-name-'
set :aws_keep_prev_no_of_ami, 1
```

To call this task after deploy,  in your desire capistrano environment file
add the following in deploy section

```ruby
 namespace :deploy do
    after :finishing, 'autoscaling:update_ami'
 end
```

And to update autoscale group launch template manually

```ruby
    cap [stage] autoscaling:update_ami
```
i.e [stage] can be staging or production

## How this works

1. Fetch only running instances that have an auto scaling group name you specified
2. Create AMI with first healthy instance
3. Tag AMI with autoscale group name
4. Wait for AMI to be available for use
5. Update Launch template with update AMI
6. Deleting stale images base on (aws_keep_prev_no_of_ami) variable
   if not set will only keep the latest one
   and delete the other AMI tagged with autoscale group name


## Contributing

1. Fork it ( https://github.com/Aftab-Akram/capistrano3-asg-ami/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

To test while developoing just `bundle console` on the project root directory and execute
`Capistrano::AutoScaling::VERSION` for a quick test
