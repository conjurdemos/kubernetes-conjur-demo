#!/usr/bin/env groovy

pipeline {
  agent { label "executor-v2" }

  options {
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: "30"))
  }

  triggers {
    cron(getDailyCronString())
  }

  stages {
    stage ("Deploy Demos") {
      steps {
        script {
          ["oss", "dap"].each { deployment ->
            stage ("Deploy demos with ${deployment} deployment") {
              stage("Deploy demos with Postgres") {
                parallel "GKE, v5 Conjur, Postgres, ${deployment}": {
                  sh "cd ci && summon --environment gke ./test gke 5 postgres ${deployment}"
                },
                "OpenShift v3.9, v5 Conjur, Postgres, ${deployment}": {
                  sh "cd ci && summon --environment oc ./test oc 5 postgres ${deployment}"
                },
                "OpenShift v3.10, v5 Conjur, Postgres, ${deployment}": {
                  sh "cd ci && summon --environment oc310 ./test oc 5 postgres ${deployment}"
                },
                "OpenShift v3.11, v5 Conjur, Postgres, ${deployment}": {
                  sh "cd ci && summon --environment oc311 ./test oc 5 postgres ${deployment}"
                }
              }

              stage("Deploy demos with MySQL") {
                parallel "GKE, v5 Conjur, MySQL, ${deployment}": {
                  sh "cd ci && summon --environment gke ./test gke 5 mysql ${deployment}"
                },
                "OpenShift v3.9, v5 Conjur, MySQL, ${deployment}": {
                  sh "cd ci && summon --environment oc ./test oc 5 mysql ${deployment}"
                },
                "OpenShift v3.10, v5 Conjur, MySQL, ${deployment}": {
                  sh "cd ci && summon --environment oc310 ./test oc 5 mysql ${deployment}"
                },
                "OpenShift v3.11, v5 Conjur, MySQL, ${deployment}": {
                  sh "cd ci && summon --environment oc311 ./test oc 5 mysql ${deployment}"
                }
              }
            }
          }
        }
      }
    }
  }

  post {
    always {
      cleanupAndNotify(currentBuild.currentResult)
    }
  }
}
