require 'spec_helper'
require './app/controllers/nodes_controller'

describe NodesController do

  let(:http_env){
    {
      'HTTP_AUTHORIZATION' => 'Bearer d03ebb195dbe6385a7caeda699f9930ff2e49f29c381ed82dc95aa642a7660b8',
      'CONTENT_TYPE' => 'application/json'
    }
  }

  before do
    stub_user('dwarner')
    stub_access_token('dwarner')
    stub_definitions
  end

  it 'Flows' do
    get "/Flows",{}, http_env
    expect(last_response.status).to eq 200
  end

  

  context 'create' do

    before do
      stub_definitions
      stub_job_creation
      stub_ip
      stub_node
    end

    it 'clusters' do
      body = {
        "sds_name" => "ceph",
        "sds_version" => "10.2.5",
        "sds_parameters" => {
          "name" => "MyCluster",
          "fsid" => "140cd3d5-58e4-4935-a954-d946ceff371d",
          "public_network" => "192.168.128.0/24",
          "cluster_network" => "192.168.220.0/24",
          "conf_overrides" => {
            "global" => {
              "osd_pool_default_pg_num" => 128,
              "pool_default_pgp_num" => 1
            }
          }
        },
        "node_identifier" => "ip",
        "node_configuration" => {
          "10.0.0.24" => {
            "role" => "ceph/mon",
            "provisioning_ip" => "10.0.0.24",
            "monitor_interface" => "eth0"
          },
          "10.0.0.29" => {
            "role" => "ceph/osd",
            "provisioning_ip" => "10.0.0.29",
            "journal_size" => 5192,
            "journal_colocation" => "false",
            "storage_disks" => [
              {
                "device" => "/dev/sda",
                "journal" => "/dev/sdc"
              },
              {
                "device" => "/dev/sdb",
                "journal" => "/dev/sdc"
              }
            ]
          },
          "10.0.0.30" => {
            "role" => "ceph/osd",
            "provisioning_ip" => "10.0.0.30",
            "journal_colocation" => true,
            "storage_disks" => [
              {
                "device" => "/dev/sda"
              },
              {
                "device" => "/dev/sdb"
              }
            ]
          }
        }
      }
      post '/CreateCluster', body.to_json, http_env
      expect(last_response.status).to eq 202
    end

  end

  context 'list' do

    before do
      stub_nodes
      stub_clusters(false)
    end

    it 'nodes' do
      get "/nodes", {}, http_env
      expect(last_response.status).to eq 200
    end

  end

  context 'node agent' do

    before do
      stub_nodes
      stub_job_creation
    end

    it 'generate journal mapping' do
      body = { 
        "Cluster.node_configuration" => {
          "c573b8b8-2488-4db7-8033-27b9a468bce3" => {
            "storage_disks" => [
              {"device" => "/dev/vdb", "size" => 189372825600, "ssd" => false},
              {"device" => "/dev/vdc", "size" => 80530636800, "ssd" => false},
              {"device" => "/dev/vdd", "size" => 107374182400, "ssd" => false},
              {"device" => "/dev/vde", "size" => 21474836480, "ssd" => false},
              {"device" => "/dev/vdf", "size" => 26843545600, "ssd" => false }
            ]
          }
        }
      }
      post '/GenerateJournalMapping', body.to_json, http_env
      expect(last_response.status). to eq 202
    end
    
  end

  context 'expand' do

    before do
      stub_definitions
      stub_job_creation
    end

    it 'gluster cluster' do
      body = {
        'sds_name' => 'gluster',
        'Cluster.node_configuration' => {
          '867d6aae-fb98-4060-9f6a-1da4e4988db8' => {
            'role' => 'glusterfs/node',
            'provisioning_ip' => '0.0.0.0'
          }
        }
      }
      put '/6b4b84e0-17b3-4543-af9f-e42000c52bfc/ExpandCluster', body.to_json, http_env
      expect(last_response.status).to eq 202
    end

    it 'ceph cluster' do
      body = {
        'sds_name' => 'ceph',
        'Cluster.node_configuration' => {
          '867d6aae-fb98-4060-9f6a-1da4e4988db8' => {
            'role' => 'ceph/mon',
            'provisioning_ip' => '0.0.0.0',
            'monitor_interface' => 'eth0'
          },
          "d41d073f-db4e-4abf-8018-02b30254b912" => {
            "role" => "ceph/osd",
            "provisioning_ip" => "0.0.0.0",
            "journal_size" => 5120,
            "journal_colocation" => false,
            "storage_disks" => [
              {"device" => "/dev/vdb", "journal" => "/dev/vdc"},
              {"device" => "/dev/vdd", "journal" => "/dev/vde"}
            ]
          }
        }
      }
      put '/6b4b84e0-17b3-4543-af9f-e42000c52bfc/ExpandCluster', body.to_json, http_env
      expect(last_response.status).to eq 202
    end
  end


end

