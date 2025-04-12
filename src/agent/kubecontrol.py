import os
from datetime import datetime, timezone
from kubernetes import client, config

class KubeControl:
    def __init__(self, namespace="default", kubeconfig_path=None):
        """
        Initialize the KubeControl class with the specified namespace and kubeconfig path.
        
        :param namespace: The Kubernetes namespace to operate in.
        :param kubeconfig_path: Optional path to the kubeconfig file. If None, it uses the default kubeconfig.
        """
        self.namespace = namespace

        try:
            # Determine whether we are running inside the cluster
            if os.getenv('KUBERNETES_SERVICE_HOST'):
                config.load_incluster_config()
            else:
                config.load_kube_config(config_file=kubeconfig_path) if kubeconfig_path else config.load_kube_config()
        except Exception as e:
            raise Exception(f"Failed to initialize Kubernetes client: {e}")
        
        self.v1 = client.CoreV1Api()
        self.apps_v1 = client.AppsV1Api()

    def get_configmap_data(self, configmap: str):
        """
        Retrieve a value from a Kubernetes ConfigMap.
        
        :param configmap: The name of the ConfigMap.
        :return: The data from the ConfigMap as a dictionary.
        """
        try:
            cm = self.v1.read_namespaced_config_map(name=configmap, namespace=self.namespace)
            return cm.data
        except client.rest.ApiException as e:
            print(f"Error retrieving ConfigMap {configmap}: {e}")
            return None
        
    def set_configmap_data(self, configmap: str, data: dict):
        """
        Update an existing Kubernetes ConfigMap with new data,
        or create a new ConfigMap if it does not exist.

        :param configmap: The name of the ConfigMap.
        :param data: A dictionary containing the data for the ConfigMap.
        :return: The updated or created ConfigMap object.
        """
        try:
            # Try to read the existing ConfigMap
            cm = self.v1.read_namespaced_config_map(name=configmap, namespace=self.namespace)
            # Update existing ConfigMap data
            cm.data.update(data)
            updated_cm = self.v1.patch_namespaced_config_map(name=configmap, namespace=self.namespace, body=cm)
            return updated_cm
        except client.rest.ApiException as e:
            if e.status == 404:
                # ConfigMap does not exist; create it
                print(f"ConfigMap {configmap} not found, creating new one.")
                body = client.V1ConfigMap(
                    metadata=client.V1ObjectMeta(name=configmap),
                    data=data
                )
                created_cm = self.v1.create_namespaced_config_map(namespace=self.namespace, body=body)
                return created_cm
            else:
                print(f"Error updating/creating ConfigMap {configmap}: {e}")
                return None
            
    def restart_deployment(self, deployment_name: str):
        """
        Trigger a rolling restart of a Deployment by patching its template annotation.

        :param deployment_name: The name of the Deployment to restart.
        """
        try:
            now = datetime.now(timezone.utc).isoformat() + "Z" 
            patch = {
                "spec": {
                    "template": {
                        "metadata": {
                            "annotations": {
                                "kubectl.kubernetes.io/restartedAt": now
                            }
                        }
                    }
                }
            }
            
            updated_deployment = self.apps_v1.patch_namespaced_deployment(
                name=deployment_name,
                namespace=self.namespace,
                body=patch
            )
            
            print(f"Deployment {deployment_name} restarted at {now}.")
            return updated_deployment
        except client.rest.ApiException as e:
            print(f"Error restarting Deployment {deployment_name}: {e}")
            return None

