# TestCase
1. Инициализируем terraform:
```
terraform init
```
2. Устанавливаем компоненты istio через helm:
```
terraform apply -target=helm_release.istio_base  -target=helm_release.istiod -target=helm_release.istio_ingress -auto-approve
```

Если `helm_release.istio_ingress` долго создается (около 2х минут), то рекомендуется выполнить команду в соседнем терминале:
```
watch kubectl get all -n istio-system
```
И посмотреть статус пода `istio-ingressgateway`, в моем случае в статусе были ошибки `ErrImagePull` и `ImagePullBackOff`

Для решения этой ситуации, можно удалить под по имени (смотрим в выводе предыдущей команды), после чего образ спуллится корректно, также выполним `minikube tunnel` для инициализации LoadBalancer, пример команды ниже, имя пода подставить свое.
```
kubectl delete po istio-ingressgateway-869fb76dc-kr8b9 -n istio-system && minikube tunnel
```
Либо можно удалить под следующей командой:
```
kubectl delete po $(kubectl get po -n istio-system | grep istio-ingressgateway | awk '{print $1}') -n istio-system
```
Если все поды в статусе running, а `helm_release.istio_ingress` все ещё создается, то выполняем только:
```
minikube tunnel
```
После этого создание ресурса helm_release.istio_ingress должно завершиться.

3. Создаем namespace, deployment и service для httpd и создаем сущности istio: gateway и virtual_service с помощью команды ниже:
```
terraform apply -target=kubernetes_namespace.httpd  -target=kubernetes_manifest.httpd_deployment -target=kubernetes_manifest.httpd_service -target=kubernetes_manifest.gateway -target=kubernetes_manifest.virtual_service -auto-approve
```
4. Проверяем работу приложения, для этого смотрим EXTERNAL-IP сервиса istio-ingressgateway в выводе команды `kubectl get svc -n istio-system` и делаем  curl на указанный IP. Либо с помощью такой команды:
```
curl $(kubectl get svc -n istio-system | grep istio-ingressgateway | awk '{print $4}')
```

Ожидаемый результат - стандартный apache html:
```
<html><body><h1>It works!</h1></body></html>
```

Версии kubectl, terraform и helm, на которых все это проверялось:
```
kubectl version

Client Version: v1.31.2
Kustomize Version: v5.4.2
Server Version: v1.31.0
------------------------------------
terraform --version
Terraform v1.5.7
on linux_amd64
------------------------------------
helm version
version.BuildInfo{Version:"v3.16.2", GitCommit:"13654a52f7c70a143b1dd51416d633e1071faffb", GitTreeState:"clean", GoVersion:"go1.22.7"}
```
