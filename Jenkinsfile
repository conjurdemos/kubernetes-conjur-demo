#!/usr/bin/env groovy

pipeline {
  agent { label 'executor-v2' }

  options {
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '30'))
  }

  triggers {
    cron(getDailyCronString())
  }

  stages {
    // Postgres Tests
    stage('Deploy Demos Postgres') {
      parallel {
        stage('GKE, v5 Conjur, Postgres') {
          steps {
            sh 'cd ci && summon --environment gke ./test gke 5 postgres dap'
          }
        }

        stage('OpenShift v3.9, v5 Conjur, Postgres') {
          steps {
            sh 'cd ci && summon --environment oc ./test oc 5 postgres dap'
          }
        }

        stage('OpenShift v3.10, v5 Conjur, Postgres') {
          steps {
            sh 'cd ci && summon --environment oc310 ./test oc 5 postgres dap'
          }
        }

        stage('OpenShift v3.11, v5 Conjur, Postgres') {
          steps {
            sh 'cd ci && summon --environment oc311 ./test oc 5 postgres dap'
          }
        }
      }
    }

    // MySQL Tests
    stage('Deploy Demos MySQL') {
      parallel {
        stage('GKE, v5 Conjur, MySQL') {
          steps {
            sh 'cd ci && summon --environment gke ./test gke 5 mysql dap'
          }
        }

        stage('OpenShift v3.9, v5 Conjur, MySQL') {
          steps {
            sh 'cd ci && summon --environment oc ./test oc 5 mysql dap'
          }
        }

        stage('OpenShift v3.10, v5 Conjur, MySQL') {
          steps {
            sh 'cd ci && summon --environment oc310 ./test oc 5 mysql dap'
          }
        }

        stage('OpenShift v3.11, v5 Conjur, MySQL') {
          steps {
            sh 'cd ci && summon --environment oc311 ./test oc 5 mysql dap'
          }
        }
      }
    }

    stage('Deploy Demos Conjur OSS') {
      parallel {
//         stage('GKE, v5 Conjur, MySQL') {
//           steps {
//             sh 'cd ci && summon --environment gke ./test gke 5 mysql oss'
//           }
//         }

        stage('OpenShift v3.9, v5 Conjur, MySQL') {
          steps {
            sh 'cd ci && summon --environment oc ./test oc 5 mysql oss'
          }
        }

        stage('OpenShift v3.10, v5 Conjur, MySQL') {
          steps {
            sh 'cd ci && summon --environment oc310 ./test oc 5 mysql oss'
          }
        }

        stage('OpenShift v3.11, v5 Conjur, MySQL') {
          steps {
            sh 'cd ci && summon --environment oc311 ./test oc 5 mysql oss'
          }
        }

//         stage('GKE, v5 Conjur, Postgres') {
//           steps {
//             sh 'cd ci && summon --environment gke ./test gke 5 postgres oss'
//           }
//         }

        stage('OpenShift v3.9, v5 Conjur, Postgres') {
          steps {
            sh 'cd ci && summon --environment oc ./test oc 5 postgres oss'
          }
        }

        stage('OpenShift v3.10, v5 Conjur, Postgres') {
          steps {
            sh 'cd ci && summon --environment oc310 ./test oc 5 postgres oss'
          }
        }

        stage('OpenShift v3.11, v5 Conjur, Postgres') {
          steps {
            sh 'cd ci && summon --environment oc311 ./test oc 5 postgres oss'
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
