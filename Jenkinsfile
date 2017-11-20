#!/usr/bin/groovy
@Library('github.com/fabric8io/fabric8-pipeline-library@master')
def utils = new io.fabric8.Utils()
clientsNode{
  def envStage = utils.environmentNamespace('stage')
  def newVersion = ''

  checkout scm
  stage('Build Release')
  echo 'NOTE: running pipelines for the first time will take longer as build and base docker images are pulled onto the node'
  echo "NOTE: JOB_NAME = ${env.JOB_NAME}""

  newVersion = performCanaryRelease {}

  def rc = """
    {
      "apiVersion" : "v1",
      "kind" : "Template",
      "labels" : { },
      "metadata" : {
        "annotations" : {
          "description" : "Fabric8 namespace migration Ceylon tool",
          "fabric8.${env.JOB_NAME}/iconUrl" : "https://raw.githubusercontent.com/eclipse/che/master/ide/che-core-ide-stacks/src/main/resources/stacks-images/type-ceylon.svg"
        },
        "labels" : { },
        "name" : "${env.JOB_NAME}"
      },
      "objects" : [{
        "kind": "ReplicationController",
        "apiVersion": "v1",
        "metadata": {
            "name": "${env.JOB_NAME}",
            "generation": 1,
            "creationTimestamp": null,
            "labels": {
                "component": "${env.JOB_NAME}",
                "container": "java",
                "group": "fabric8-migration",
                "project": "${env.JOB_NAME}",
                "provider": "fabric8",
                "expose": "true",
                "version": "${newVersion}"
            },
            "annotations": {
                "fabric8.${env.JOB_NAME}/iconUrl" : "https://raw.githubusercontent.com/eclipse/che/master/ide/che-core-ide-stacks/src/main/resources/stacks-images/type-ceylon.svg"
            }
        },
        "spec": {
            "replicas": 1,
            "selector": {
                "component": "${env.JOB_NAME}",
                "container": "java",
                "group": "fabric8-migration",
                "project": "${env.JOB_NAME}",
                "provider": "fabric8",
                "version": "${newVersion}"
            },
            "template": {
                "metadata": {
                    "creationTimestamp": null,
                    "labels": {
                        "component": "${env.JOB_NAME}",
                        "container": "java",
                        "group": "fabric8-migration",
                        "project": "${env.JOB_NAME}",
                        "provider": "fabric8",
                        "version": "${newVersion}"
                    }
                },
                "spec": {
                    "containers": [
                        {
                            "name": "${env.JOB_NAME}",
                            "image": "${env.FABRIC8_DOCKER_REGISTRY_SERVICE_HOST}:${env.FABRIC8_DOCKER_REGISTRY_SERVICE_PORT}/${env.KUBERNETES_NAMESPACE}/${env.JOB_NAME}:${newVersion}",
                            "ports": ],
                            "env": [
                                {
                                    "name": "KUBERNETES_NAMESPACE",
                                    "valueFrom": {
                                        "fieldRef": {
                                            "apiVersion": "v1",
                                            "fieldPath": "metadata.namespace"
                                        }
                                    }
                                }
                            ],
                            "resources": {},
                            "terminationMessagePath": "/dev/termination-log",
                            "imagePullPolicy": "IfNotPresent",
                            "securityContext": {}
                        }
                    ],
                    "restartPolicy": "OnFailure",
                    "terminationGracePeriodSeconds": 30,
                    "dnsPolicy": "ClusterFirst",
                    "securityContext": {}
                }
            }
        },
        "status": {
            "replicas": 1
        }
    }]}
    """

  stage('Rollout to Stage')
  kubernetesApply(file: rc, environment: envStage)
}