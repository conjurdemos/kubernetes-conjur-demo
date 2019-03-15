#!/usr/bin/env groovy

pipeline {
  agent { label 'executor-v2' }

  options {
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '30'))
  }

  stages {
    stage('Deploy Demos') {
      parallel {

// Postgres Tests

        stage('GKE, v4 Conjur, Postgres') {
          steps {
            sh 'cd ci && summon -e gke ./test gke 4 postgres'
          }
        }

        stage('GKE, v5 Conjur, Postgres') {
          steps {
            sh 'cd ci && summon -e gke ./test gke 5 postgres'
          }
        }

        stage('OpenShift v3.9, v4 Conjur, Postgres') {
          steps {
            sh 'cd ci && summon -e oc ./test oc 4 postgres'
          }
        }

        stage('OpenShift v3.9, v5 Conjur, Postgres') {
          steps {
            sh 'cd ci && summon -e oc ./test oc 5 postgres'
          }
        }    
             
// MySQL Tests
        
        stage('GKE, v4 Conjur, MySQL') {
          steps {
            sh 'cd ci && summon -e gke ./test gke 4 mysql'
          }
        }

        stage('GKE, v5 Conjur, MySQL') {
          steps {
            sh 'cd ci && summon -e gke ./test gke 5 mysql'
          }
        }

        stage('OpenShift v3.9, v4 Conjur, MySQL') {
          steps {
            sh 'cd ci && summon -e oc ./test oc 4 mysql'
          }
        }

        stage('OpenShift v3.9, v5 Conjur, MySQL') {
          steps {
            sh 'cd ci && summon -e oc ./test oc 5 mysql'
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
