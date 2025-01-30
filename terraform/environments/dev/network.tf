resource "google_compute_network" "default" {
  name    = "simple-adb"
  project = "680560386191"
}


resource "google_compute_global_address" "private_ip_alloc" {
  project       = "680560386191"
  name          = "adb-psa"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = 12
  network       = google_compute_network.default.id
  address       = "172.16.0.0"
}

resource "google_service_networking_connection" "vpc_connection" {
  network                 = google_compute_network.default.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
  deletion_policy         = "ABANDON"
}
