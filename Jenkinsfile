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
    // Postgres Tests with Host-ID-based Authn
    stage('Deploy Demos Postgres with Host-ID-based Authn') {
      parallel {
        stage('GKE, v5 Conjur, Postgres, Host-ID-based Authn') {
          steps {
            sh 'cd ci && summon --environment gke ./test gke postgres host-id-based'
          }
        }

        stage('OpenShift v3.11, v5 Conjur, Postgres, Host-ID-based Authn') {
          steps {
            sh 'cd ci && summon --environment oc311 ./test oc postgres host-id-based'
          }
        }

        stage('OpenShift v4.3, v5 Conjur, Postgres, Host-ID-based Authn') {
          steps {
            sh 'cd ci && summon --environment oc43 ./test oc postgres host-id-based'
          }
        }

        stage('OpenShift v4.5, v5 Conjur, Postgres, Host-ID-based Authn') {
          steps {
            sh 'cd ci && summon --environment oc45 ./test oc postgres host-id-based'
          }
        }
      }
    }

    // Postgres Tests with Annotation-based Authn
    stage('Deploy Demos Postgres with Annotation-based Authn') {
      parallel {
        stage('GKE, v5 Conjur, Postgres, Annotation-based Authn') {
          steps {
            sh 'cd ci && summon --environment gke ./test gke postgres annotation-based'
          }
        }

        stage('OpenShift v3.11, v5 Conjur, Postgres, Annotation-based Authn') {
          steps {
            sh 'cd ci && summon --environment oc311 ./test oc postgres annotation-based'
          }
        }

        stage('OpenShift v4.3, v5 Conjur, Postgres, Annotation-based Authn') {
          steps {
            sh 'cd ci && summon --environment oc43 ./test oc postgres annotation-based'
          }
        }

        stage('OpenShift v4.5, v5 Conjur, Postgres, Annotation-based Authn') {
          steps {
            sh 'cd ci && summon --environment oc45 ./test oc postgres annotation-based'
          }
        }
      }
    }

    // MySQL Tests
    stage('Deploy Demos MySQL') {
      parallel {
        stage('GKE, v5 Conjur, MySQL, Host-ID-based Authn') {
          steps {
            sh 'cd ci && summon --environment gke ./test gke mysql host-id-based'
          }
        }

        stage('OpenShift v3.11, v5 Conjur, MySQL, Host-ID-based Authn') {
          steps {
            sh 'cd ci && summon --environment oc311 ./test oc mysql host-id-based'
          }
        }

        stage('OpenShift v4.3, v5 Conjur, MySQL, Host-ID-based Authn') {
          steps {
            sh 'cd ci && summon --environment oc43 ./test oc mysql host-id-based'
          }
        }

        stage('OpenShift v4.5, v5 Conjur, MySQL, Host-ID-based Authn') {
          steps {
            sh 'cd ci && summon --environment oc45 ./test oc mysql host-id-based'
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
