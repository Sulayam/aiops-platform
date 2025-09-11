pipeline {
  agent any

  environment {
    IMAGE   = "sulayam/aiops-agent-api"
    VERSION = "v1.0.${BUILD_NUMBER}"
  }

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  parameters {
    booleanParam(name: 'DEPLOY_TO_EC2', defaultValue: false)
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
        sh 'ls -la'
      }
    }

    stage('Smoke Test') {
      steps {
        dir('agent-api') {
          sh '''set -e
python3 -V
# Create & use a local venv in the workspace (no system installs)
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
python - <<'PY'
print("smoke: fastapi+requests import test")
import fastapi, requests
print("smoke ok")
PY
'''
        }
      }
    }

    stage('Docker Build') {
      steps {
        sh 'docker build -t ${IMAGE}:${VERSION} ./agent-api'
      }
    }

    stage('Docker Push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                          usernameVariable: 'U',
                                          passwordVariable: 'P')]) {
          sh '''set -e
echo "$P" | docker login -u "$U" --password-stdin
docker push ${IMAGE}:${VERSION}
docker tag ${IMAGE}:${VERSION} ${IMAGE}:latest
docker push ${IMAGE}:latest
'''
        }
      }
    }

    stage('Deploy to EC2 (toggle)') {
      when { expression { return params.DEPLOY_TO_EC2 } }
      steps {
        echo 'We’ll wire EC2 deploy next (sshagent + docker compose up -d)'
      }
    }
  }

  post {
    success { echo "OK → ${IMAGE}:${VERSION}" }
    failure { echo 'FAILED' }
  }
}
