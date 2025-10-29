data "vsphere_datacenter" "datacenter" {
  name = var.vsphere_datacenter
}

# Compute clusters for multi-site deployment
data "vsphere_compute_cluster" "compute_cluster_vlb" {
  name          = var.vsphere_compute_cluster_vlb
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_compute_cluster" "compute_cluster_her" {
  name          = var.vsphere_compute_cluster_her
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

# Datastores for multi-site deployment
data "vsphere_datastore" "datastore_vlb" {
  name          = var.vsphere_datastore_vlb
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_datastore" "datastore_her" {
  name          = var.vsphere_datastore_her
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "network" {
  name          = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_virtual_machine" "talos_template" {
  name          = var.vsphere_talos_template
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

resource "vsphere_folder" "folder" {
  path          = var.vsphere_folder
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

# see https://www.terraform.io/docs/providers/vsphere/r/virtual_machine.html
resource "vsphere_virtual_machine" "controller" {
  count                       = var.controller_count
  folder                      = vsphere_folder.folder.path
  name                        = "${var.prefix}-${local.controller_nodes[count.index].name}"
  guest_id                    = data.vsphere_virtual_machine.talos_template.guest_id
  firmware                    = data.vsphere_virtual_machine.talos_template.firmware
  num_cpus                    = 4
  num_cores_per_socket        = 4
  memory                      = 4 * 1024
  wait_for_guest_net_routable = false
  wait_for_guest_net_timeout  = 0
  wait_for_guest_ip_timeout   = 0
  enable_disk_uuid            = true # NB the VM must have disk.EnableUUID=1 for, e.g., k8s persistent storage.
  
  # Multi-site distribution: even-numbered VMs go to VLB, odd-numbered to Herstal
  resource_pool_id            = count.index % 2 == 0 ? data.vsphere_compute_cluster.compute_cluster_vlb.resource_pool_id : data.vsphere_compute_cluster.compute_cluster_her.resource_pool_id
  datastore_id                = count.index % 2 == 0 ? data.vsphere_datastore.datastore_vlb.id : data.vsphere_datastore.datastore_her.id
  
  scsi_type                   = data.vsphere_virtual_machine.talos_template.scsi_type
  disk {
    unit_number      = 0
    label            = "os"
    size             = max(data.vsphere_virtual_machine.talos_template.disks[0].size, 40) # [GiB]
    eagerly_scrub    = data.vsphere_virtual_machine.talos_template.disks[0].eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.talos_template.disks[0].thin_provisioned
  }
  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.talos_template.network_interface_types[0]
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.talos_template.id
  }
  # NB this extra_config data ends-up inside the VM .vmx file.
  # NB guestinfo.talos.config is only applied at bootstrap time.
  #    After that, we manage the cluster with talosctl upgrade and ArgoCD.
  extra_config = {
    "guestinfo.talos.config" = base64encode(data.talos_machine_configuration.controller[count.index].machine_configuration)
  }
  lifecycle {
    ignore_changes = [
      ept_rvi_mode,
      hv_mode,
      extra_config["guestinfo.talos.config"],
    ]
  }
}

# see https://www.terraform.io/docs/providers/vsphere/r/virtual_machine.html
resource "vsphere_virtual_machine" "worker" {
  count                       = var.worker_count
  folder                      = vsphere_folder.folder.path
  name                        = "${var.prefix}-${local.worker_nodes[count.index].name}"
  guest_id                    = data.vsphere_virtual_machine.talos_template.guest_id
  firmware                    = data.vsphere_virtual_machine.talos_template.firmware
  num_cpus                    = 4
  num_cores_per_socket        = 4
  memory                      = 4 * 1024
  wait_for_guest_net_routable = false
  wait_for_guest_net_timeout  = 0
  wait_for_guest_ip_timeout   = 0
  enable_disk_uuid            = true # NB the VM must have disk.EnableUUID=1 for, e.g., k8s persistent storage.
  
  # Multi-site distribution: even-numbered VMs go to VLB, odd-numbered to Herstal
  resource_pool_id            = count.index % 2 == 0 ? data.vsphere_compute_cluster.compute_cluster_vlb.resource_pool_id : data.vsphere_compute_cluster.compute_cluster_her.resource_pool_id
  datastore_id                = count.index % 2 == 0 ? data.vsphere_datastore.datastore_vlb.id : data.vsphere_datastore.datastore_her.id
  
  scsi_type                   = data.vsphere_virtual_machine.talos_template.scsi_type
  disk {
    unit_number      = 0
    label            = "os"
    size             = max(data.vsphere_virtual_machine.talos_template.disks[0].size, 40) # [GiB]
    eagerly_scrub    = data.vsphere_virtual_machine.talos_template.disks[0].eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.talos_template.disks[0].thin_provisioned
  }
  disk {
    unit_number      = 1
    label            = "data"
    size             = 60 # [GiB]
    eagerly_scrub    = data.vsphere_virtual_machine.talos_template.disks[0].eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.talos_template.disks[0].thin_provisioned
  }
  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.talos_template.network_interface_types[0]
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.talos_template.id
  }
  # NB this extra_config data ends-up inside the VM .vmx file.
  # NB guestinfo.talos.config is only applied at bootstrap time.
  #    After that, we manage the cluster with talosctl upgrade and ArgoCD.
  extra_config = {
    "guestinfo.talos.config" = base64encode(data.talos_machine_configuration.worker[count.index].machine_configuration)
  }
  lifecycle {
    ignore_changes = [
      ept_rvi_mode,
      hv_mode,
      extra_config["guestinfo.talos.config"],
    ]
  }
}
