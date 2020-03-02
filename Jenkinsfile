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
        //stage('GKE, v5 Conjur, Postgres') {
        //  steps {
        //    sh 'cd ci && summon --environment gke ./test gke postgres'
        //  }
        //}

        //stage('GKE, v5 Conjur, Postgres, Deployment Authn ID') {
        //  steps {
        //    sh 'cd ci && CONJUR_AUTHN_LOGIN_RESOURCE=deployment summon --environment gke ./test gke postgres'
        //  }
        //}

        //stage('OpenShift v3.9, v5 Conjur, Postgres') {
        //  steps {
        //    sh 'cd ci && summon --environment oc ./test oc postgres'
        //  }
        //}

        stage('OpenShift v3.9, v5 Conjur, Postgres, Deployment Authn ID') {
          steps {
            sh 'cd ci && CONJUR_AUTHN_LOGIN_RESOURCE=deployment_config summon --environment oc ./test oc postgres'
          }
        }

        //stage('OpenShift v3.10, v5 Conjur, Postgres') {
        //  steps {
        //    sh 'cd ci && summon --environment oc310 ./test oc postgres'
        //  }
        //}

        //stage('OpenShift v3.11, v5 Conjur, Postgres') {
        //  steps {
        //    sh 'cd ci && summon --environment oc311 ./test oc postgres'
        //  }
        //}

        stage('OpenShift v3.11, v5 Conjur, Postgres, Deployment Authn ID') {
          steps {
            sh 'cd ci && CONJUR_AUTHN_LOGIN_RESOURCE=deployment_config summon --environment oc311 ./test oc postgres'
          }
        }
      }
    }

// MySQL Tests
//    stage('Deploy Demos MySQL') {
//      parallel {
//        stage('GKE, v5 Conjur, MySQL') {
//          steps {
//            sh 'cd ci && summon --environment gke ./test gke mysql'
//          }
//        }
//
//        stage('OpenShift v3.9, v5 Conjur, MySQL') {
//          steps {
//            sh 'cd ci && summon --environment oc ./test oc mysql'
//          }
//        }
//
//        stage('OpenShift v3.10, v5 Conjur, MySQL') {
//          steps {
//            sh 'cd ci && summon --environment oc310 ./test oc mysql'
//          }
//        }
//
//        stage('OpenShift v3.11, v5 Conjur, MySQL') {
//          steps {
//            sh 'cd ci && summon --environment oc311 ./test oc mysql'
//          }
//        }
//      }
//    }
  }

  post {
    always {
      cleanupAndNotify(currentBuild.currentResult)
    }
  }
}
