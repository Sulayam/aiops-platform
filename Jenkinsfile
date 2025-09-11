pipeline {
  agent any

  environment {
    IMAGE   = "sulayam/aiops-agent-api"
    VERSION = "v1.0.${BUILD_NUMBER}"
  }

  options { timestamps(); disableConcurrentBuilds() }
  parameters { booleanParam(name: 'DEPLOY_TO_EC2', defaultValue: false) }

  stages {
    stage('Checkout')  { steps { checkout scm } }

    stage('Smoke Test') {
      steps {
        dir('agent-api') {
          sh '''
            python3 -V || true
            pip3 install -r requirements.txt || true
            python3 -c "import fastapi, requests; print('imports ok')"
          '''
        }
      }
    }

    stage('Docker Build') {
      steps { sh "docker build -t ${IMAGE}:${VERSION} ./agent-api" }
    }

    stage('Docker Push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'U', passwordVariable: 'P')]) {
          sh '''
            set -e
            echo "$P" | docker login -u "$U" --password-stdin
            docker push '"${IMAGE}:${VERSION}"'
            docker tag ${IMAGE}:${VERSION} ${IMAGE}:latest
            docker push ${IMAGE}:latest
          '''
        }
      }
    }

    stage('Deploy to EC2 (toggle)') {
      when { expression { return params.DEPLOY_TO_EC2 } }
      steps {
        echo "We’ll wire EC2 deploy next (sshagent + docker compose up -d)"
      }
    }
  }

  post {
    success { echo "OK → ${IMAGE}:${VERSION}" }
    failure { echo "FAILED" }
  }
}
