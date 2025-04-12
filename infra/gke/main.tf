resource "google_service_account" "gke_sa" {
  account_id   = "gke-sa"
  display_name = "GKE Monitoring and Logging Service Account"
}

resource "google_project_iam_member" "gke_sa_role" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

resource "google_project_iam_member" "gke_sa_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

resource "google_compute_network" "vpc_network" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name                     = "${var.cluster_name}-subnet"
  ip_cidr_range            = "10.0.0.0/16"
  region                   = var.region
  network                  = google_compute_network.vpc_network.id
  private_ip_google_access = true
}

resource "google_compute_router" "router" {
  name    = "${var.cluster_name}-router"
  network = google_compute_network.vpc_network.id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.cluster_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_container_cluster" "autopilot_cluster" {
  name     = var.cluster_name
  location = var.region

  network    = google_compute_network.vpc_network.id
  subnetwork = google_compute_subnetwork.subnet.id

  enable_autopilot = true

  release_channel {
    channel = "REGULAR"
  }

  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account = google_service_account.gke_sa.email
    }
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  deletion_protection = false
}

resource "google_pubsub_topic" "etl_topic" {
  name = var.pubsub_topic_name
}

resource "google_pubsub_subscription" "etl_subscription" {
  name  = var.pubsub_subscription_name
  topic = google_pubsub_topic.etl_topic.name

  ack_deadline_seconds = 30

  retain_acked_messages = false
  message_retention_duration = "86400s"  # 1 day

}

data "google_project" "project" {
  project_id = var.project_id
}


resource "google_pubsub_subscription_iam_member" "ksa_subscriber_binding" {
  project      = var.project_id
  subscription = google_pubsub_subscription.etl_subscription.name
  role         = "roles/pubsub.subscriber"
  member       = "principal://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/${var.namespace}/sa/${var.etl_ksa_name}"
}

resource "google_pubsub_topic_iam_member" "ksa_publisher_binding" {
  project = var.project_id
  topic   = google_pubsub_topic.etl_topic.name
  role    = "roles/pubsub.publisher"
  member  = "principal://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/${var.namespace}/sa/${var.etl_ksa_name}"
}
