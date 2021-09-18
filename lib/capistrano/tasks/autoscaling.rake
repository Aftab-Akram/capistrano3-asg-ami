require 'active_support'
require 'active_support/time'

require 'aws-sdk-ec2'
require 'aws-sdk-autoscaling'


namespace :autoscaling do

  desc 'Update AMI from Auto Scaling Group.'
  task :update_ami do
    region = fetch(:aws_region)
    key = fetch(:aws_access_key_id)
    secret = fetch(:aws_secret_access_key)
    group_name = fetch(:aws_autoscaling_group_name)

    credentials = {
      region: region,
      credentials: Aws::Credentials.new(key, secret)
    }
    instances_of_as = get_instances(credentials, group_name)

    instances_of_as.each { |instance|
      if instance.health_status != 'Healthy'
        puts "Autoscaling: Skipping unhealthy instance #{instance.instance_id}"
      else
        update_ami(credentials, instance.instance_id, group_name)
      end
    }
  end

  # Get Autoscale Group Instance Info
  def get_instances(credentials, group_name)
    as = Aws::AutoScaling::Client.new(credentials)
    instances_of_as = as.describe_auto_scaling_groups(
      auto_scaling_group_names: [group_name],
      max_records: 1,
    ).auto_scaling_groups[0].instances

    instances_of_as
  end

  # 1- Create AMI
  # 2- Tag AMI with autoscale group name
  # 3- Wait for AMI to be available for use
  # 4- Update Launch template with update AMI
  # 5- Deleting stale images base on (aws_keep_prev_no_of_ami) variable
  #    if not set will only keep the latest one
  #    and delete the other AMI tag with autoscale group name
  def update_ami(credentials, instance_id, group_name)
    ec2 = Aws::EC2::Resource.new(credentials)
    ec_instance = ec2.instance(instance_id)
    ami_prefix = fetch(:aws_autoscale_ami_prefix) || ''
    launch_template_id = fetch(:aws_launch_template_id)
    aws_keep_prev_no_of_ami = fetch(:aws_keep_prev_no_of_ami) || 1
    return if launch_template_id.nil?
    return unless fetch(:asg_ami_id).nil?

    puts "Creating AMI# #{ami_prefix}#{Time.current.strftime("%F--%H-%M")} with first healthy instance"
    resp = ec_instance.create_image(
      name: "#{ami_prefix}#{Time.current.strftime("%F--%H-%M")}",
    )
    set :asg_ami_id, resp.id # Saving AMI ID in current context to avoid duplicate AMI's

    puts "Tagging AMI# #{ami_prefix}#{Time.current.strftime("%F--%H-%M")} with autoscale group name"
    resp.create_tags({
                       tags: [
                         {
                           key: 'autoscaling_group_name',
                           value: group_name
                         },
                       ],
                     })

    puts "\n================================================================="
    puts 'Lanuch Template will only be updated if image is available for use.'
    puts 'In case connection broken, or any unexpected error'
    puts 'Either re-run the script OR update launch template at AWS with latest AMI id when AMI available'
    puts '================================================================='
    puts "\nWating for AMI# #{resp.id} to be available. This will take some time 4-8 minutes(appox) 😴"
    ec2_client = Aws::EC2::Client.new(credentials)
    ec2_client.wait_until(:image_available, { image_ids: [resp.id] })

    puts "Updating Launch Template# #{launch_template_id}  with latest AMI# #{resp.id}"
    ec2_client.create_launch_template_version({
                                                launch_template_data: {
                                                  image_id: resp.id,
                                                },
                                                launch_template_id: launch_template_id,
                                                source_version: '$Latest',
                                                version_description: 'updateAMI',
                                              })
    puts "Launch Template# #{launch_template_id} with latest AMI updated"

    puts "Keeping #{aws_keep_prev_no_of_ami}# latest AMI's and cleaning the rest"
    cleaning_ami(credentials, group_name)
    puts 'AMI updated Finished'
  end

  def cleaning_ami(credentials, group_name)
    ec2 = Aws::EC2::Resource.new(credentials)
    aws_keep_prev_no_of_ami = fetch(:aws_keep_prev_no_of_ami) || 1
    images = amis_by_group_name_tag(ec2, group_name)
    images = images.sort_by { |x| Date.parse x.creation_date }.reverse
    return unless images.count > aws_keep_prev_no_of_ami

    images = images[aws_keep_prev_no_of_ami..-1] || []
    images.each do |ami|
      snapshots = snapshots_attached_to(ec2, ami)
      puts "Deleting #{ami.id}# AMI"
      ami.deregister

      puts "Deleting #{ami.id}# AMI snapshots"
      delete_snapshots(snapshots)

      puts "#{ami.id}# AMI deleted"
    end
  end

  def amis_by_group_name_tag(ec2, group_name)
    ec2.images(owners: ['self']).to_a.select do |image|
      image.tags.any? { |k| k.key == 'autoscaling_group_name' && k.value == group_name }
    end
  end

  def snapshots_attached_to(ec2, image)
    ids = image.block_device_mappings.map(&:ebs).compact.map(&:snapshot_id)
    ec2.snapshots(snapshot_ids: ids)
  end

  def delete_snapshots(snapshots)
    snapshots.each do |snapshot|
      snapshot.delete unless snapshot.nil?
    end
  end
end