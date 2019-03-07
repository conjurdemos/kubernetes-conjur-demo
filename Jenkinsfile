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
        stage('GKE and v4 Conjur') {
          steps {
            sh 'cd ci && summon -e gke ./test gke 4'
          }
        }

        stage('GKE and v5 Conjur') {
          steps {
            sh 'cd ci && summon -e gke ./test gke 5'
          }
        }

        stage('OpenShift v3.9 and v4 Conjur') {
          steps {
            sh 'cd ci && summon -e oc ./test oc 4'
          }
        }

        stage('OpenShift v3.9 and v5 Conjur') {
          steps {
            sh 'cd ci && summon -e oc ./test oc 5'
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
