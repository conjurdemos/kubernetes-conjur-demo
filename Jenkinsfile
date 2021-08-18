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

  parameters { 
    booleanParam(
      name: 'TEST_OCP_NEXT',
      description: 'Whether or not to run the pipeline against the next OCP version',
      defaultValue: false) 
  }

  stages {
    // Postgres Tests with Host-ID-based and Annotation-based Authn against OSS
    stage('Deploy Demos against OSS on Openshift') {
      parallel {
        stage('OpenShift v(current), v5 Conjur OSS, Postgres, Host-ID-based Authn') {
          steps {
            sh 'cd ci && CONJUR_OSS=true summon --environment current ./test oc postgres host-id-based'
          }
        }

        stage('OpenShift v(current), v5 Conjur OSS, Postgres, Annotation-based Authn') {
          steps {
            sh 'cd ci && CONJUR_OSS=true summon --environment current ./test oc postgres annotation-based'
          }
        }

        stage('OpenShift v(next)') {
          when {
            expression { params.TEST_OCP_NEXT }
          }
          stages {
            stage('OpenShift v(next), v5 Conjur OSS, Postgres, Host-ID-based Authn') {
              steps {
                sh 'cd ci && CONJUR_OSS=true summon --environment next ./test oc postgres host-id-based'
              }
            }
            stage('OpenShift v(next), v5 Conjur OSS, Postgres, Annotation-based Authn') {
              steps {
                sh 'cd ci && CONJUR_OSS=true summon --environment next ./test oc postgres annotation-based'
              }
            }
          }
        }
      }
    }
    // Postgres Tests with Host-ID-based Auth
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

        stage('OpenShift v(oldest), v5 Conjur, Postgres, Host-ID-based Authn') {
          steps {
            sh 'cd ci && summon --environment oldest ./test oc postgres host-id-based'
          }
        }

        stage('OpenShift v(current), v5 Conjur, Postgres, Host-ID-based Authn') {
          steps {
            sh 'cd ci && summon --environment current ./test oc postgres host-id-based'
          }
        }

        stage('OpenShift v(next)') {
          when { 
            expression { params.TEST_OCP_NEXT } 
          }

          stages {
            stage('OpenShift v(next), v5 Conjur, Postgres, Host-ID-based Authn') {
              steps {
                sh 'cd ci && summon --environment next ./test oc postgres host-id-based'
              }
            }
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

        stage('OpenShift v(oldest), v5 Conjur, Postgres, Annotation-based Authn') {
          steps {
            sh 'cd ci && summon --environment oldest ./test oc postgres annotation-based'
          }
        }

        stage('OpenShift v(current), v5 Conjur, Postgres, Annotation-based Authn') {
          steps {
            sh 'cd ci && summon --environment current ./test oc postgres annotation-based'
          }
        }

        stage('OpenShift v(next)') {
          when {
            expression { params.TEST_OCP_NEXT }
          }

          stages {
            stage('OpenShift v(next), v5 Conjur, Postgres, Annotation-based Authn') {
              steps {
                sh 'cd ci && summon --environment next ./test oc postgres annotation-based'
              }
            }
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

        stage('OpenShift v(oldest), v5 Conjur, MySQL, Host-ID-based Authn') {
          steps {
            sh 'cd ci && summon --environment oldest ./test oc mysql host-id-based'
          }
        }

        stage('OpenShift v(current), v5 Conjur, MySQL, Host-ID-based Authn') {
          steps {
            sh 'cd ci && summon --environment current ./test oc mysql host-id-based'
          }
        }
        stage('OpenShift v(next)') {
          when {
            expression { params.TEST_OCP_NEXT }
          }

          stages {
            stage('OpenShift v(next), v5 Conjur, MySQL, Host-ID-based Authn') {
              steps {
                sh 'cd ci && summon --environment next ./test oc mysql host-id-based'
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
