## Kubernates でのコンテナ実行

※GKEで動作確認しています。

```bash
# Persistent Volume Claimを実行 (DB用の永続ボリューム)
kubectl apply -f pvc.yml
kubectl get pvc  # pvcを確認
> NAME      STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
> dj-disk   Bound     pvc-bb9b04fa-5ce8-11e9-a37b-42010aaa003d   5Gi        RWO            standard       11s

kubectl get pv   # pvを確認
> NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS    CLAIM             STORAGECLASS   REASON    AGE
> pvc-bb9b04fa-5ce8-11e9-a37b-42010aaa003d   5Gi        RWO            Delete           Bound     default/dj-disk   standard                 1m
```

```bash
# PostgreSQLのdeploymentを作成
$ kubectl apply -f deployment-pg.yml
$ kubectl get deployments  # deploymentを確認
> NAME      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
> pg        1         1         1            0           11s

$ kubectl get pods  # podを確認
> NAME                  READY     STATUS    RESTARTS   AGE
> pg-745b45644b-269bk   1/1       Running   0          51s
```
このときPodのSTATUSがRunningでなければ `kubectl describe <pod-name>` や `kubectl logs <pod-name>` で調査を行う。

```bash
# PostgreSQLのserviceを作成
$ kubectl apply -f service-pg.yml
$ kubectl get services  # serviceを確認
> NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
> kubernetes   ClusterIP   10.51.240.1     <none>        443/TCP    1h
> pgsvc        ClusterIP   10.51.245.227   <none>        5432/TCP   6s
```
データベース用のサービスタイプはデフォルト(ClusterIP)で作成するので EXTERNAL-IPは無し。

```
# Postgresのコンテナに入る
$ kubectl exec -it pg-745b45644b-269bk /bin/bash

# Django用のDBROLEとDATABASEを作成する
root@pg-745b45644b-269bk:# psql -U postgres
> psql (11.2 (Debian 11.2-1.pgdg90+1))
> Type "help" for help.

postgres=# CREATE ROLE "user" WITH LOGIN CREATEDB PASSWORD 'password';
> CREATE ROLE
postgres=# CREATE DATABASE "Polls";
> CREATE DATABASE
postgres=# \q

root@pg-745b45644b-269bk:# exit
```

```bash
# Djangoのdeploymentを作成する
$ kubectl apply -f deployment-dj.yml
$ kubectl get deployments  # deploymentを確認
> NAME      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
> dj        3         3         3            3           17s
> pg        1         1         1            1           18m

$ kubectl get pods  # podを確認
> NAME                  READY     STATUS    RESTARTS   AGE
> dj-64c786b695-k8vlj   1/1       Running   0          22s
> dj-64c786b695-pt9cs   1/1       Running   0          22s
> dj-64c786b695-qxq72   1/1       Running   0          22s
> pg-745b45644b-269bk   1/1       Running   0          18m

# DjangoのService (Loadbalancer) を作成する
$ kubectl apply -f service-dj.yml
$ kubectl get services --watch  # serviceを確認
> NAME         TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
> djsvc        LoadBalancer   10.51.247.191   <pending>     8000:30052/TCP   11s
> kubernetes   ClusterIP      10.51.240.1     <none>        443/TCP          2h
> pgsvc        ClusterIP      10.51.245.227   <none>        5432/TCP         17m

> djsvc     LoadBalancer   10.51.247.191   34.92.29.247   8000:30052/TCP   1m
```
EXTERNAL-IPが確定するまでには少し時間がかかる。

manage.pyからDBの初期化と管理者ユーザーの登録を行う。
```
$ kubectl exec -it dj-64c786b695-k8vlj /bin/bash

[root@dj-64c786b695-k8vlj django_gs]# python3.6 manage.py migrate
> Operations to perform:
>   Apply all migrations: admin, auth, contenttypes, polls, sessions
> Running migrations:
>   Applying contenttypes.0001_initial... OK
>   Applying auth.0001_initial... OK
>   Applying admin.0001_initial... OK
>   Applying admin.0002_logentry_remove_auto_add... OK
>   Applying admin.0003_logentry_add_action_flag_choices... OK
>   Applying contenttypes.0002_remove_content_type_name... OK
>   Applying auth.0002_alter_permission_name_max_length... OK
>   Applying auth.0003_alter_user_email_max_length... OK
>   Applying auth.0004_alter_user_username_opts... OK
>   Applying auth.0005_alter_user_last_login_null... OK
>   Applying auth.0006_require_contenttypes_0002... OK
>   Applying auth.0007_alter_validators_add_error_messages... OK
>   Applying auth.0008_alter_user_username_max_length... OK
>   Applying auth.0009_alter_user_last_name_max_length... OK
>   Applying polls.0001_initial... OK
>   Applying sessions.0001_initial... OK

[root@dj-64c786b695-k8vlj django_gs]# python3.6 manage.py createsuperuser
> Username (leave blank to use 'root'): admin
> Email address: admin@example.com
> Password:
> Password (again):
> Superuser created successfully.

[root@dj-64c786b695-k8vlj django_gs]# exit
> exit
```

以上でDjangoのチュートリアルサイトに接続できるので、http://34.92.29.247:8000/polls/ へブラウザから接続します。  
ただし、内容を登録していないので管理者ログインから http://34.92.29.247:8000/admin/login/ データ登録を行う必要があります。
