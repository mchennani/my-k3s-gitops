## Lab K3s GitOps : Multi-site avec ArgoCD & Helm

Ce projet démontre la mise en place d'une infrastructure **GitOps** complète permettant de déployer plusieurs sites web distincts à partir d'un seul "moteur" (Chart Helm) sur un cluster **K3s**.

#### Architecture du Lab

* **Cluster** : K3s (Kubernetes léger).
* **Réseau** : 
  * **MetalLB** : Pour l'attribution d'une IP fixe au cluster (`192.168.1.200`).
  * **Ingress-Nginx** : Pour le routage des noms de domaine (`app.lab`, `blog.lab`).
* **Déploiement** : ArgoCD (mode Auto-Sync & Self-Healing).
* **Templating** : Helm (Chart unique pour plusieurs environnements).

#### Structure du Projet

```text
.
├── mon-app/                  # Le Chart Helm (le moteur)
│   ├── Chart.yaml
│   ├── values.yaml           # Config par défaut (Site Principal)
│   └── templates/
│       ├── deployment.yaml   # Déploiement flexible (volumes dynamiques)
│       ├── ingress.yaml      # Routage HTTP
│       ├── service.yaml      # Exposition interne
│       ├── configmap-app.yaml# Contenu HTML Site Principal
│       └── configmap-blog.yaml# Contenu HTML Blog
└── values-blog.yaml          # Surcharge pour le deuxième site (Blog)
```

#### Concepts Clés Appris

1. **Le flux GitOps**

Toute modification effectuée dans ce dépôt et "poussée" (git push) est instantanément détectée par ArgoCD qui met à jour le cluster sans intervention manuelle.

2. **Multi-Tenancy avec Helm**

Nous utilisons le même code (dossier mon-app) pour déployer deux sites différents en variant simplement les fichiers de valeurs :

- **App Principal** : 3 réplicas, utilise `values.yaml`.

- **Blog** : 1 réplica, utilise `values-blog.yaml`.
3. **Injection de contenu (ConfigMaps)**

Le contenu HTML des sites n'est pas figé dans l'image Nginx. Il est injecté via des ConfigMaps montées comme des volumes, permettant de modifier le texte du site directement depuis Git.

#### Comment tester ?

**Configuration DNS Locale**

Ajouter l'IP du cluster dans votre fichier **/etc/hosts** (ou **C:\Windows\System32\drivers\etc\hosts)** :

```text
192.168.1.200 app.lab
192.168.1.200 blog.lab
```

**Accès aux sites**

- Site Principal : **http://app.lab** (3 pods, version Alpine)

- Blog : **http://blog.lab** (1 pod)

#### Commandes Utiles

- **Vérifier les Ingress** : 
  
  ```
  kubectl get ingress -n mon-app
  ```
- **Voir les Pods** : 
  
  ```
  kubectl get pods -n mon-app
  ```
- **Forcer un redémarrage** : 
  
  ```
  kubectl rollout restart deployment [nom] -n mon-app
  ```

---

#### Explication des Scripts et Fichiers

| Fichier                     | Rôle                                                                                                                                            |
|:--------------------------- |:----------------------------------------------------------------------------------------------------------------------------------------------- |
| **`install-complet.sh`**    | **Le lanceur automatique**. Il installe K3s, Helm, MetalLB, Ingress-Nginx et ArgoCD. Il configure aussi l'IP fixe et l'accès `http://argo.lab`. |
| **`mon-app/` (Chart Helm)** | **Le moteur unique**. Contient les templates Kubernetes. C'est ce dossier qu'ArgoCD utilise pour créer les ressources sur le cluster.           |
| **`values.yaml`**           | **Config Site Principal**. Définit 3 réplicas et utilise la ConfigMap `cm-site-principal`.                                                      |
| **`values-blog.yaml`**      | **Surcharge pour le Blog**. Modifie la config pour n'avoir qu'un seul réplica et utiliser `cm-site-blog`.                                       |

---

#### Détails du script `install-complet.sh`

Ce script automatise les tâches complexes pour éviter les erreurs manuelles :

1. **Installation Système** : Installe K3s en mode "propre" (sans le LoadBalancer par défaut).
2. **Couche Réseau** : Déploie **MetalLB** pour que ton cluster réponde à l'IP `192.168.1.200`.
3. **Point d'Entrée** : Installe **Ingress-Nginx** pour diriger le trafic selon le nom de domaine (`app.lab`, `blog.lab`, `argo.lab`).
4. **Auto-Gestion** : Installe **ArgoCD** en mode `insecure` (pour laisser Ingress gérer le HTTP) et crée la route `argo.lab`.

#### Comment ça marche techniquement ?

Lorsque vous tapez `http://blog.lab` :

1. Votre PC envoie la requête à **192.168.1.200** (grâce au fichier `/etc/hosts`).
2. **MetalLB** intercepte la requête et la donne à l'**Ingress-Nginx**.
3. L'Ingress lit l'hôte (`blog.lab`) et redirige vers le **Service** du blog.
4. **ArgoCD** s'assure que si vous modifiez le code sur Git, tout cela reste à jour automatiquement.
