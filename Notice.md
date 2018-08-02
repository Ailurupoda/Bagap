
# <p style="text-align: center;"> Suivi de bordures et de parcelles</p>
### <p style="text-align: center;"> UMR Bagap - Saint-Laurent-de-la-Prée</p>


## Introduction
Ce projet à pour but le suivi d'occupations et d'entretiens de parcelles et de bordures.

Une observation se fait sur une parcelle et une bordure à une date donnée décrite lors d'une session. La donnée est récupérée sur le terrain, puis vérifiée et validée de retour au bureau.

Cette notice détail la démarche et le fonctionnement des applications créées utilisant les logiciel Lizmap, Postgres/Postgis, QGIS et QGIS Server. Développé avec la méthode GeoPoppy pour son utilisation sur le terrain.

## <a id="up"> Sommaire </a>
* [SQL](#sql)
  * [Base](#base)
  * [Vues](#view)
  * [Fonctions](#func)
* [Interface Terrain](#field)
  * [QGIS](#pqgisF)
  * [Lizmap](#plizmapF)
  * [Utilisation](#usesF)
* [Interface Bureau](#desktop)  
  * [QGIS](#pqgisD)
  * [Lizmap](#plizmapD)
  * [Utilisation](#usesD)
* [Paramétrage GeoPoppy](#gpp)
  * [Préparation des projets](#gp_proj)
  * [Création de la base](#gp_base)
  * [Ajout du module de synchronisation](#gp_sync)
* [Synchronisation](#sync)
  * [Interface GeoPoppy](#syn_gpp)
  * [Interface serveur](#syn_serv)

***
### <a id="sql">I) SQL</a>

Les fichier *__update_keys.sql__*, *__view.sql__*, *__function.sql__* et *__trigger_maj_bordure.sql__* listent les modifications apportées à la base de données.

#### <a id="pqgisF"> A - update_keys.sql </a>

Réorganise la base de données en ajoutant, modifiant et supprimant des colonnes et des contraintes sur les tables.
  * Ajout des champs de géométrie
  * Modification des clé primaires et étrangères
  * Mise à jour des données en fonction des nouvelles contraintes
  * Ajout de la table histo_fusion listant les entités à fusionner
  * Ajout d'un utilisateur "Terrain" pour une modification des observation seulement sur la session courante.

#### <a id="pqgisF"> B - view.sql </a>
Créé les vues utilisées pour les interfaces.
  * *mv_zone*

  Cette vue créé et liste la géométrie des zones par l'union des parcelles de chacune des zones (connues par la première lettre de leur code).
  * *v_mod_session*

  Cette vue récupère simplement les informations relationnelles d'une session pour pouvoir afficher ces valeurs à la place des identifiant des clés étrangères.
  * *v_mod_bordure*

  Cette vue récupère simplement les informations relationnelles d'une bordure pour pouvoir afficher ces valeurs à la place des identifiant des clés étrangères.
  * *v_observation_bordure*

  Cette vue liste les observations réalisées sur la session courante avec la géométrie des bordures. Si aucune observation n'est encore signalée, une entité est tout de même créée avec des valeurs par défaut. C'est la vue qui va nous servir pour l'insertion des observation de bordure par des entités géographiques sur l'interface terrain de notre application.
  * *v_observation_bordure_tot*

  Cette vue liste toutes les observations réalisée couplée à la géométrie des bordures. Elle est utilisée pour afficher les observations des bordures sur l'interface bureau et simplifier l'interaction.
  * *v_observation_surface*

  Cette vue liste les observations réalisées sur la session courante avec la géométrie des parcelles. Si aucune observation n'est encore signalée, une entité est tout de même créée avec les valeurs des dernières observation effectuées sur la parcelle. C'est la vue qui va nous servir pour l'insertion des observation de parcelles par des entités géographiques sur l'interface terrain de notre application.
  * *v_observation_surface_tot*

  Cette vue liste toutes les observations réalisée couplée à la géométrie des parcelles. Elle est utilisée pour afficher les observations des parcelles sur l'interface bureau et simplifier l'interaction.  
  * *v_observation_fusion*

  Certaines parcelles peuvent évoluer dans le temps et fusionner, mais la fusion n'est visualisable que sur le terrain. Ainsi, une observation sur une parcelle fusionnée par l'union de trois autres se fait en réalité sur les trois parcelles. C'est avec cette vue que l'on récupère les informations des observations concernant les parcelles fusionnées. On créé ainsi des entités virtuelles fusionnées qui vont pouvoir avec un trigger réorienter les données dans les parcelles à l'origine de la fusion.
  * *mv_fusion_surface*

  Cette vue matérialiser liste les géométries des parcelles qui ont fusionnées.

#### <a id="pqgisF"> C - function.sql </a>
Créé les fonctions de calcul et d'insertion.
  * *fun_create_bordure()*

 Cette fonction est utilisée une seule fois et permet la création de la géométrie des bordures. La géométrie d'une bordure correspond alors à un buffer de la lisière coupé par rapport à la parcelle correspondante à la bordure.
  * *fun_repare_bordure()*

  Cette fonction est utilisée une seule fois et réalise une correction de la géométrie des bordures pour éviter les superpositions. Elle va supprimer les parties superposées sur la bordure comprenant la surface la plus grande, dans le but de garder une zone cliquable suffisamment importante.
  * *fun_warning() -  <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction active automatiquement les warnings lorsqu'un commentaire est entrée dans une table.
  * *fun_edit_session() - <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction gère l'utilisation des session. Elle contraint la mise à jour étape par étape. La création d'une session n'est possible que la dernière session est validée. Il ne peut y avoir qu'une seule fois la même étape d'une session à l'exception de l'état "terminé".
  Il reste cependant possible de revenir à l'état "en cours", lorsque l'état courent est "à valider". Elle se lance lorsqu'une modification se fait sur la table session.
  * *fun_close_session() - <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction change automatiquement l'état de la session à "à validée" lorsque toutes les observation ont été réalisés. Elle est lancée pour chacune des nouvelles observation et calcul si c'est la dernière observation ou s'il en reste d'autre.
  * *fun_edit_terrain() - <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction restreint les modification de l'utilisateur terrain. Elle insère la donnée seulement si la session concernée est la courante, elle renvois une erreur dans le cas contraire.
  * *fun_edit_from_obs() - <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction met automatiquement à jour une session à l'état "en cours" lorsqu'une observation est ajoutée sur une session à l'état "créée".
  * *fun_obs_bord_maj() - <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction rend possible l'édition d'une vue. Elle détourne l'insertion de la vue "v_observation_bordure" vers la table "observation_bordure".
  * *fun_obs_surf_maj() - <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction rend possible l'édition d'une vue. Elle détourne l'insertion de la vue "v_observation_surface" vers la table "observation_surface".
  * *fun_tri_intersect_fusion() - <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction gère l'insertion des parcelles à fusionner. Elle met à jour les champs "hf_surf_id" et "hf_surf_ref" en fonction de l'intersection entre le point et les parcelles, ainsi que le numéro de l'union.
  La dernière étape est de recharger la vue matérialisée des fusions des parcelles.
  * *fun_tri_obs_fusion() - <span style='color:#4A1A2C'>Trigger</span>*

  Cette fonction rend possible l'édition d'une vue. Elle détourne l'insertion de la vue "v_observation_fusion" vers la table "observation_surface".

![MLD](bagap_MLD.png)
***
### <a id="field">II)	Interface terrain</a>`    `[up](#up)

Cette interface est vouées à être utilisée sur le terrain.

Les contraintes pour cet affichage sont :
* Ajouter des observations dans le cas où une session est présente
* Modifier seulement les observations de la session en cours
* Afficher les observations de la dernière session
* Suivre l'avancement du parcours sur le terrain


#### <a id="pqgisF"> A - Projet QGIS </a>`    `[up](#up)

Les couches contenus dans ce projet sont les suivantes :
<img src="/ScreenShot/Field/01_liste_couches.png" width="30%">

* __<span style='color:#96CA2D'>lisiere :</span>__ Affichage géographique des lisières.    

* __<span style='color:#046380'>v_observation_bordure :</span>__ Affichage géographique des observation de bordures de la session courante.

* __<span style='color:#046380'>v_observation_fusion :</span>__ Affichage géographique des observation de surfaces fusionnées.

* __<span style='color:#046380'>v_observation_surface:</span>__ Affichage géographique des observation de surfaces courante ou de la dernière session.

* __<span style='color:#333333'>mv_zone: </span>__ Affichage géographique des trois zones de suivi.

* __<span style='color:#01B0F0'>utilisation_sol :</span>__ Couche donnant les valeurs relationnelles des types d'utilisation et d'occupation du sol.

* __<span style='color:#01B0F0'>etat_surface:</span>__ Couche donnant les valeurs relationnelles des types d'état d'une surface.

* __<span style='color:#BD8D46'>session :</span>__ Couche donnant l'information sur l'état des sessions. Seulement les deux dernières sont prises en compte.

* __<span style='color:#8E3557'>v_mod_session :</span>__ Couche donnant les valeurs sous forme de libellé pour l'affichage des sessions dans la table attributaire. Cette couche est jointe à la couche session.

* __<span style='color:#01B0F0'>observateur :</span>__ Couche donnant les valeurs relationnelles des observateurs d'une session.

* __<span style='color:#01B0F0'>etat_session :</span>__ Couche donnant les valeurs relationnelles des états d'une session.

  * <span style='color:#96CA2D'> Entités géographiques présentes pour la reconnaissance du terrain.</span>

  * <span style='color:#046380'>  Entités présentes pour l'ajout d'information par modification de la base de données de façon géographique.</span>

  * <span style='color:#333333'>  Entités présentes pour zoomer rapidement sur les entités voulues.</span>

  * <span style='color:#01B0F0'>  Entités présentes pour afficher les valeurs relationnelles sous forme de libellé dans les popups et formulaires d'édition.</span>

  * <span style='color:#BD8D46'>  Entités présentes pour donner des informations supplémentaires et non géographiques.</span>

  * <span style='color:#8E3557'>  Entités présentes pour afficher les valeurs relationnelles sous forme de libellé dans la table attributaire. </span>

###### Paramétrage des champs
L'affichage dans lizmap utilise les paramètres de QGIS. Nous allons donc définir les champs que nous voulons voir dans les popups et les formulaires d'édition. Pour ce faire, nous allons dans les *__propriétés de la couche__* puis dans l'onglet *__Champs__*
* *Session*

Les session vont être affichées sous forme de table attributaire, nous avons donc besoin d'ajouter une jointure pour récupérer les champs sous forme de libellés. Cette couche est également éditable, tous les champs doivent donc apparaître dans une popup.

![MLD](/ScreenShot/Field/02_session_champs.png)

  1. <span style='color:#1cda49'>  Champs provenant de la jointure qui seront affichés dans la table attributaire de Lizmap </span>
  2. <span style='color:#ff0000'> Champs cachés à l'utilisateur mais prenant des valeurs automatiquement dans la base de données</span>
  3. <span style='color:#2d90f6'> Champs à afficher pour l'utilisateur avec un Alias compréhensible et des valeurs relationnelles ajoutés pour remplacer les champs clés étrangères par des libellés </span>


* *Observation bordures*

Les observations de bordure seront simplement afficher à l'aide de popups et éditables. La couche contenant des champs booléens, il faut les afficher sous la forme de case à cocher et donner en alias des noms pertinents. De plus, la table contient un grand nombre de champs, nous décidons donc de les regrouper par des onglets à l'affichage. De la même façon que la session des champs vont rester caché du fait qu'ils ne sont pas utiles à l'utilisateur, mais important tout de même pour la base de données.

![MLD](/ScreenShot/Field/03_v_obs_bordure_champs.png)

1. <span style='color:#2d90f6'> Mise en forme de boîte à cocher avec comme valeur TRUE (coché) et FALSE (décoché) </span>
2. <span style='color:#27ba43'> Organisation du formulaire par cliquer/glisser sous forme d'onglets </span>


* *Observation surface*

Les couches fusion et surface possèdent les mêmes type d'entité, leur paramétrage est ainsi identique. Nous utilisons le cliquer/glisser pour n'afficher que les champs qui nous intéressent. Nous utilisons également les valeurs relationnelles, cachées, boîte à cocher vues précédemment.

![MLD](/ScreenShot/Field/05_v_obs_surface_champs.png)

###### Paramétrage de la symbologie
La symbologie est importante pour une meilleure visualisation de l'avancement du travail. Sur l'interface dédiée au terrain, nous voulons pouvoir repérer d'un coup d'oeil le travail que nous venons d'effectuer. Nous recherchons donc ici à différencier les données à enregistrer des données déjà présentes. La symbologie se fera donc sur les couches concernant les observations (de bordure et de surface). Afin de ne pas mélanger les entités, nous donnons deux couple de couleur différentes, une pour les bordures et l'autre pour les parcelles.


![MLD](/ScreenShot/Field/06_v_obs_bordure_style.png)
1.  Remplissage vert clair pour indiquer les observation réalisée pour la session en en cours
2.  Remplissage rouge pour les observations qui ne sont pas encore renseignées pour la session courante.

![MLD](/ScreenShot/Field/07_v_obs_surface_style.png)
1.  Remplissage bleu pour les observations qui ne sont pas réalisée et pour contraster avec le vert des bordures.
2.  Remplissage rouge pour les observations qui ne sont pas encore réalisées. Les points noir sont présent pour contraster la symbologie des bordures.

#### <a id="plizmapF"> B - Paramètres Lizmap </a>`    `[up](#up)

Cette interface doit permettre la modification des observations sur les parcelles et sur les bordures. Il doit aussi rendre possible la modification de l'état de la session une fois que celle-ci est finie.

###### Paramétrage des actions
* Edition

Nous ajoutons les couches éditable dans l'onglet *__'Édition des couches'__* .
Pour chacune des couches, nous cochons l'option *__'Modifier les attributs'__* ainsi que *__'Supprimer'__* , excepté pour la couche session.

   ![MLD](/ScreenShot/Field/09_param_edition.png)

* Table attributaire

Ajouter les couches dans l'onglet *__'Table attributaire'__* permet d'afficher les données des couches dans un tableau sur l'interface. C'est aussi en les ajoutant dans cet onglet, que l'on peut utiliser le trie par localisation de la couche, ainsi que les relations parent/enfant qui filtrent les enfants en fonction de l'entité parent.

Ici, nous voulons simplement visualiser les données de la table session, mais nous ajoutons aussi la table mv_zone en cochant l'option *__'Masquer la couche dans la liste'__* puisque nous n'avons pas besoin de voir les données, mais nous utilisons la localisation sur la couche.


   ![MLD](/ScreenShot/Field/10_param_attributaire.png)

* Localisation par couche

La localisation par couche permet de filtrer les données d'une couche en fonction des attributs spécifiés. Si l'entité est géographique, il est possible de zoomer dessus. Nous l'utilisons ici pour centrer la carte sur la zone sur laquelle nous voulons enregistrer les observations.

   ![MLD](/ScreenShot/Field/11_param_locate_zone.png)

###### <a id="affich"> Paramétrage de l'affichage </a>

La configuration de l'affichage se fait dans l'onglet *__'Couches'__* du plugin Lizmap dans la partie *__'Popup'__* de la couche sélectionnée. En sélectionnant 'lizmap' comme source, il est possible de modifier les informations à afficher par la popup avec un balisage HTML. Cela est utile pour embellir l'affichage, ou pour ne montrer que certains champs.

Ici nous souhaitons avoir une vision simplifier des champs des couches d'observation. Nous utilisons un tableau avec des fonds de couleur intercalés une fois sur deux et les valeurs booléennes sont en majuscule.

* Bordures


   ![MLD](/ScreenShot/Field/12_param_bordure_config.png)
*  Parcelles 'fusion'


   ![MLD](/ScreenShot/Field/13_param_fusion_config.png)

* Parcelles


   ![MLD](/ScreenShot/Field/14_param_surface_config.png)


#### <a id="usesF"> C - Utilisations </a>

Cette application est très simple à utiliser, nous allons voir les différentes fonctionnalités et comment les atteindre.

Les premiers éléments à regarder sont les couches géographiques, nous avons Lisière, Bordures, Surfaces et les parcelles fusionnées. Ces dernières ont la même symbologie que Surfaces puisqu'elles complètent les informations.

<p style="text-align:center;">
![MLD](/ScreenShot/Field/Uses/01_couches.png)
</p>

La partie filtrant les différentes zones est très simple d'utilisation. Il suffit de choisir dans le cadre "Locating" la lettre concernant notre zone. Ici nous avons sélectionné la A, ce qui a centré la carte et détouré la zone en jaune.

<p style="text-align:center;">
![MLD](/ScreenShot/Field/Uses/02_loc.png)
</p>

Nous passons maintenant au fonctionnement de l'ajout des observations sur nos parcelles. Nous pouvons dors et déjà voir en bleu les parcelles sur lesquelles nous avont déjà réalisé nos observations lors de la session. Nous nous penchons donc sur une parcelle en rouge pour notifier l'observation.

En cliquant sur la parcelle, celle-ci est détourée en jaune et une popup s'ouvre à gauche de l'écran, nous renseignant sur le contenu actuel de la parcelle.
Nous pouvons ainsi constater le numéro, la session, un commentaire, l'état et l'occupation du sol. Ces informations concernent alors bien la session précédente.

Nous allons donc passer à l'édition de l'information en cliquant sur le bouton en forme de crayon.

<p style="text-align:center;">
![MLD](/ScreenShot/Field/Uses/03_click_parcelle.png)
</p>

Le formulaire d'édition remplace de fait la popup et on y retrouve exactement les mêmes informations. Nous pouvons ainsi modifier l'état, l'occupation et la hauteur, modifier le commentaire. Il faut bien penser à changer la session, sans quoi, l'édition n'aura pas lieu et une erreur apparaîtra.

<p style="text-align:center;">
![MLD](/ScreenShot/Field/Uses/04_edit_parcelle.png)
</p>

Un fois la donnée sauvegarder en cliquant sur le bouton "save", nous pouvons voir à l'écran que la couleur à changer et est passé au bleu. De plus un message nous signalant que la donnée a bien été sauvegardée est visible en haut de l'écran.

<p style="text-align:center;">
![MLD](/ScreenShot/Field/Uses/05_fin_parcelle.png)
</p>
Nous suivons le même procédé pour le renseignement sur les bordures. En la sélectionnant, elle devient entouré de jaune et la popup s'affiche contenant toutes les informations actuelle. Pour les bordures coloré de rouge, les données sont des valeurs par défaut à faux et à la session courante, mais aucune n'est réellement présente dans la base de donnée actuellement.

![MLD](/ScreenShot/Field/Uses/06_click_bordure.png)

Lorsque l'on souhaite effectuer une édition sur une bordure, le formulaire se présente sous la forme de cinq onglet. Le premier comprenant les renseignement basique de la bordure.

![MLD](/ScreenShot/Field/Uses/07_edit_bor_1.png)

Ensuite, les onglets vont regrouper les informations en thème pour orienter l'utilisateur sur la donnée qu'il cherche à rentrer, sans qu'il ait besoin de faire défiler le formulaire indéfiniment.

<p style="text-align:center;">
![MLD](/ScreenShot/Field/Uses/08_edit_bor_2.png)![MLD](/ScreenShot/Field/Uses/09_edit_bor_3.png)
</p>

<p style="text-align:center;">
![MLD](/ScreenShot/Field/Uses/10_edit_bor_4.png)![MLD](/ScreenShot/Field/Uses/11_edit_bor_5.png)
</p>

Une fois sauvegarder, la bordure devient verte et signale ainsi que la donnée est bien sauvegardée et qu'il est possible de poursuivre notre saisie.

<p style="text-align:center;">
  ![MLD](/ScreenShot/Field/Uses/12_fin_bordure.png)
</p>

Une fois les observations réalisée sur toutes les parcelles et bordures (plus aucun morceau de rouge ne se trouve sur la carte), la session passe automatiquement à 'à valider', ce qui met fin à l'application terrain pour cette session.

Il est cependant possible de visualiser les deux dernières session et de modifier l'état de la session courante. Pour ce faire, dans l'onglet "data" il faut cliquer sur le bouton à côté de "Session".

<p style="text-align:center;">
  ![MLD](/ScreenShot/Field/Uses/13_session.png)
</p>
Il est alors possible de cliquer sur le bouton d'édition, ce qui ouvre le formulaire pour modifier les champs. Lors de cet étape, il est ainsi possible de modifier l'état pour qu'il soit "en cours" ou ""à valider", selon si on a besoin de revenir en arrière ou de forcer la fin du travail.

<p style="text-align:center;">
  ![MLD](/ScreenShot/Field/Uses/14_edit_session.png)
</p>





Avec cette interface, nous pouvons nous diriger sur le terrain et saisir simplement les données concernant les entretiens des bordures et l'état des parcelles.

   ![MLD](/ScreenShot/Field/15_interface_global.png)


***
### <a id="desktop">III) Interface bureau</a>`    `[up](#up)
Cette interface est vouées à être utilisée au bureau.

Les contraintes pour cet affichage sont :
* Visualiser les observations de toutes les sessions
* Modifier toutes les observations
* Modifier toutes les tables paramètres
* Avoir une symbologie par état de surface et occupation du sol
* Avoir une symbologie par type d'entretien de bordure.
* Pouvoir fusionner des parcelles entre elles
* Visualiser la totalité des données

#### <a id="pqgisD"> A - Projet QGIS</a> `    `[up](#up)

<img src="/ScreenShot/Desktop/01_liste_couches.png" width="30%">

* __<span style='color:#333333'>histo_fusion :</span>__ Affichage ponctuel des parcelles fusionnées.    

* __<span style='color:#96CA2D'>lisiere :</span>__ Affichage géographique des lisières.

* __<span style='color:#046380'>Strate herbacée :</span>__ Affichage géographique des observations de bordures dont les entretiens correspondent à la partie herbacée.

* __<span style='color:#046380'>Strate arbustive :</span>__ Affichage géographique des observations de bordures dont les entretiens correspondent à la partie arbustive.

* __<span style='color:#046380'>Strate arborée:</span>__ Affichage géographique des observations de bordures dont les entretiens correspondent à la partie arborée.

* __<span style='color:#046380'>Haie: </span>__ Affichage géographique des observations de bordures dont les entretiens correspondent à la partie haie.

* __<span style='color:#046380'>Autre :</span>__ Affichage géographique des observations de bordures n'ayant pas d'entretiens observé.

* __<span style='color:#046380'>Surface ocs:</span>__ Affichage géographique des observations de surfaces catégorisé suivant l'occupation du sol.

* __<span style='color:#046380'>Surface etats :</span>__ Affichage géographique des observations de surfaces catégorisé suivant l'état.

* __<span style='color:#96CA2D'>bordure :</span>__ Affichage des bordures afin de les modifier ou d'en ajouter.

* __<span style='color:#96CA2D'>surface :</span>__ Affichage des surfaces dans le but de les modifier ou d'en ajouter.

* __<span style='color:#333333'>mv_zone :</span>__ Affichage géographique des trois zones de suivi.

* __<span style='color:#BD8D46'>session_old :</span>__ Couche donnant l'information sur l'état des sessions. Seulement les deux dernières sont prises en compte.

* __<span style='color:#01B0F0'>observateur :</span>__ Couche donnant les valeurs relationnelles des observateurs d'une session.

* __<span style='color:#8E3557'>v_mod_session :</span>__ Couche donnant les valeurs sous forme de libellé pour l'affichage des sessions dans la table attributaire. Cette couche est jointe à la couche session.

* __<span style='color:#01B0F0'>etat_session :</span>__ Couche donnant les valeurs relationnelles des états d'une session.

* __<span style='color:#BD8D46'>observation_bordure :</span>__ Couche donnant les informations des observations des bordure pour chaque session.

* __<span style='color:#8E3557'>v_mod_bordure :</span>__ Couche donnant les valeurs relationnelles des observations de bordure.

* __<span style='color:#8E3557'>v_mod_observation_bordure :</span>__ Couche donnant les valeurs relationnelles des observations de bordure.

* __<span style='color:#BD8D46'>observation_surface:</span>__ Couche donnant les informations des observations des parcelles pour chaque session.

* __<span style='color:#01B0F0'>etat_surface :</span>__ Couche donnant les valeurs relationnelles des types d'état d'une surface.

* __<span style='color:#01B0F0'>utilisation_sol :</span>__ Couche donnant les valeurs relationnelles des types d'utilisation et d'occupation du sol.

* __<span style='color:#8E3557'>v_mod_observation_surface :</span>__ Couche donnant les valeurs relationnelles des observations de parcelle.

  * <span style='color:#333333'> Entités géographiques améliorant l'interprétation des données.</span>

  * <span style='color:#96CA2D'> Entités géographiques présentes pour la reconnaissance du terrain.</span>

  * <span style='color:#046380'>  Entités géographique présentes pour l'ajout d'information par modification de la base de données de façon géographique.</span>

  * <span style='color:#BD8D46'>  Entités donnant des informations supplémentaires non géographiques.</span>

  * <span style='color:#01B0F0'>  Entités présentes pour afficher les valeurs relationnelles sous forme de libellé dans les popups et formulaires d'édition.</span>

  * <span style='color:#8E3557'>  Entités présentes pour afficher les valeurs relationnelles sous forme de libellé dans la table attributaire. </span>


Pour cet interface, nous utilisons des liens parent/enfant. Nous l'utilisons d'une part pour effectuer des tris par session et d'autre part pour regrouper les observations par parcelles et visualiser son avancement.

![MLD](/ScreenShot/Desktop/02_relation_qgis.png)

Les relations ainsi créées concernent les couches d'observation. Chaque catégorie d'observation de bordure est reliée à la couche session, ce qui va rendre dynamique l'affichage des observations sur la carte en fonction des sessions. Il en est de même pour les deux symbologies des observations de parcelles.
De plus, les couche *__'observation_bordure'__* et *__'observation_surface'__* sont liées respectivement aux couches *__'bordure'__* et *__'surface'__* .

Les couches *__'Strate herbacée'__* , *__'Strate arbustive'__* , *__'Strate arborée'__* , *__'Haie'__* et *__'Autre'__* proviennent de la vue *__'v_observation_bordure'__* et sont filtrées dans QGIS en fonction de la valeur des champs provenant de la catégorie respective.

Les couches *__'Surface ocs'__* et *__'Surface etats'__* proviennent de la vue *__'v_observation_surface'__* .

###### Paramétrage des champs
Les champs sont paramétrés de la même façon que pour l'interface Terrain. Les observations pouvant être visualisées par table attributaire, nous ajoutons une vue qui, par jointure renseigne les valeurs relationnelles. La couche histo_fusion est aussi ajoutée pour fusionner les parcelles pour adapter le modèle à la réalité.

* histo_fusion

![MLD](/ScreenShot/Desktop/03_histo_champ.png)

* observation_bordure

![MLD](/ScreenShot/Desktop/04_obs_bord_champs.png)

* observation_surface

![MLD](/ScreenShot/Desktop/05_obs_surf_champs.png)

###### Paramétrage de la symbologie

Cette interface doit avoir une symbologie plus poussée que pour le terrain. En effet, nous souhaitons ici avoir une première approche de l'état des bordures et parcelles visuellement. C'est pourquoi nous avons dupliqué les couches et utilisé une classification différente sur chacune d'elles.

* Strate herbacée

![MLD](/ScreenShot/Desktop/08_obs_bord_style_herba.png)

* Strate arbustive

![MLD](/ScreenShot/Desktop/06_obs_bord_style_arbu.png)

* Strate arborée

![MLD](/ScreenShot/Desktop/09_obs_bor_style.png)

* Haies

![MLD](/ScreenShot/Desktop/07_obs_bord_style_haie.png)

* Surface ocs

![MLD](/ScreenShot/Desktop/11_obs_surf_style_OCS.png)

* Surface etats

![MLD](/ScreenShot/Desktop/10_obs_surf_style_etats.png)


* histo_fusion

Les entités de la couche fusion sont catégorisées par le champ numéro union afin de visualiser les parcelles fusionnées entre elles.

![MLD](/ScreenShot/Desktop/15_fusion_style.png)


#### <a id="plizmapD"> B - Paramètres Lizmap </a> [UP](#up)

###### Paramétrage des actions
* Edition

L'édition va se tourner sur toutes les couches. On va ainsi lister dans cet onglet, aussi bien les couches géométriques concernant les observations, mais aussi les parcelles, lisière et bordures elles-même ainsi que les tables paramètres qui gravitent autour.

![MLD](/ScreenShot/Desktop/13_param_edition.png)


* Table attributaire

Les couches concernées par l'affichage attributaire sont les entités géographiques bordure, lisière et parcelles, ainsi que les tables paramètres et les sessions. Les couches observation_surface et observation_bordure vont aussi s'y trouver en s'affichant en tant qu'enfant sous les bordures et les parcelles.

Les couches concernant les catégories d'entretiens et d'occupation du sol des parcelles vont elle aussi être ajouté dans cet onglet, mais ne seront pas visualisable. Nous les utilisons seulement pour effectuer des recherche en fonction des sessions.

![MLD](/ScreenShot/Desktop/12_param_attributaire.png)

* Localisation par couche

Les filtres géographique que nous souhaitons effectuer se font du côté des sessions et des zones. Nous ajoutons ainsi la couche session_old et la couche mv_zone qui, grâce aux relations afficheront les entités concernée.

![MLD](/ScreenShot/Desktop/14_param_locate_layer.png)

###### Paramétrage de l'affichage
Les affichages dans les popups sont basés sur les affichages de [l'interface terrain](#affich).

#### <a id="usesD"> C - Utilisations </a>`    `[up](#up)

Dans cette interface, les premières entités que l'on peut constater, sont les lisières, bordures et parcelles de toutes nos zones, ainsi que les ponctuels indiquant les couches fusionnées.

![MLD](/ScreenShot/Desktop/Use/01_visu_couches.png)

Lorsque l'on recherche les observations d'une session, il faut commencer par saisir la date de la session voulue, puis sélectionner la couche contenant la légende qui nous intéresse.
1. Sélection de la date de la session dans l'outil de localisation par couche.
2. Sélection de la couche à afficher. Les couches sont surlignées en jaune pour montrer qu'elles sont filtrées.
Ici, nous visualisons l'occupation du sol des parcelles.

![MLD](/ScreenShot/Desktop/Use/03_ocs.png)

L'image suivante montre la visualisation  de l'état des parcelles.

![MLD](/ScreenShot/Desktop/Use/04_etats.png)

Les cinqs images suivantes montrent les entretiens observés sur les bordures concernant respectivement la strate herbacée, strate arbustive, strate arborée, haie et celles où l'on a constaté aucun entretien.

![MLD](/ScreenShot/Desktop/Use/05_herbacée.png)
![MLD](/ScreenShot/Desktop/Use/06_arbustive.png)
![MLD](/ScreenShot/Desktop/Use/07_arborée.png)
![MLD](/ScreenShot/Desktop/Use/08_haies.png)
![MLD](/ScreenShot/Desktop/Use/15_autre.png)

Nous pouvons de la même façon que pour l'interface terrain, éditer les observations.

Nous allons maintenant voir comment effecteur la fusion des parcelles.
Pour commencer, il faut se rendre dans l'onglet d'édition et sélectionner la couche "Fusions".

Le formulaire présente alors deux champs à renseigner et la géométrie à créer sur la carte. Le champ "Numéro d'union", qui permet de regrouper les parcelles, possède une valeur par défaut correspondant à la dernière insertion dans la base. Ici, le 4 signifie que l'on va ajouter une entité qui fusionnera les parcelles possédant ce même numéro.

![MLD](/ScreenShot/Desktop/Use/09_fusion.png)
![MLD](/ScreenShot/Desktop/Use/10_fusion_2.png)

Pour fusionner de nouvelles parcelles, nous commençons donc par attribuer un nouveau numéro : 5, puis nous ajoutons un point sur la première parcelle à fusionner. Étant donné que c'est la première parcelle du groupe numéro 5, c'est elle qui va servir de référence. En sauvegardant le formulaire, l'entité est créée.

![MLD](/ScreenShot/Desktop/Use/11_fusion_3.png)

Afin de fusionner cette parcelle avec celle voisine, nous ajoutons de la même façon un point en faisant bien attention de garder le numéro 5 en numéro d'union.

![MLD](/ScreenShot/Desktop/Use/12_fusion_4.png)

Une fois les ponctuels de fusion renseignés, nous pouvons visualiser la couche mv_fusion_surface qui est l'union des géométries à fusionner. Ainsi, en bleu, nous avons des entités regroupées.

![MLD](/ScreenShot/Desktop/Use/13_fusion_5.png)

Avec cette application, toutes les données de la base peuvent être visualisées, ajoutées, supprimées ou modifiées.

Dans l'onglet "Table attributaire", nous avons la liste des tables de la base dont nous pouvons voir les valeurs. Il est aussi possible dans cet onglet d'éditer la donnée.

![MLD](/ScreenShot/Desktop/Use/14_attributaire.png)

Il est ainsi possible de regarder les informations concernant les bordures. En cliquant sur une bordure, cela permet de faire apparaitre les observations associées depuis le début du suivi.
1. Informations des Bordures
2. Liste des observations de la bordure sélectionné.

![MLD](/ScreenShot/Desktop/Use/16_bordure_attri.png)

De la même façon on peut suivre les observations des Parcelles.
1. Informations des Parcelles
2. Liste des observations associées à la Parcelle.

![MLD](/ScreenShot/Desktop/Use/17_obs_surface.png)

La fenêtre de table attributaire rend possible l'édition des couches. Pour l'exemple, nous avons sélectionné la couche "Etat session", nous avons ainsi les différents état présent actuellement dans la base.
1. En cliquant sur ce bouton, nous pouvons ajouter un nouveau type d'état pour une session.
2. Ce bouton est utilisé pour modifier les valeurs de la table.
3. Ici, nous supprimons la valeur. Une valeur ne peut être supprimé seulement lorsqu'elle n'est pas rattaché à une autre donnée de la base.

![MLD](/ScreenShot/Desktop/Use/18_attri_mod_entité.png)

Il est également possible d'ajouter une nouvelle donnée en accédant à l'onglet d'édition. En sélectionnant la couche pour laquelle on souhaite ajouter une valeur, et en cliquant sur le bouton "ajouter", le formulaire apparait et il suffit de remplir les champs et de valider l'édition.

![MLD](/ScreenShot/Desktop/Use/19_adding_entite.png)

&nbsp;
&nbsp;

Avec cette interface, nous pouvons manipuler nos données et corriger les données provenant du terrain. Nous avons un contrôle et un accès total aux données de la base.

![MLD](/ScreenShot/Desktop/16_interface_desktop.png)

### <a id="gpp">IV) Paramétrage GeoPoppy</a>`    `[up](#up)

Après avoir préparer la base de données et les projets Lizmap sur le serveur, il faut les paramétrer sur le Raspberry afin de pouvoir utiliser les outils sur le terrain sans connexion.

#### <a id="gp_base"> B - Création de la base</a> `    `[up](#up)

Pour commencer l'utilisation des outils sur le terrain, il faut préparer la base de données sur le Raspberry. Pour cela nous suivons les étapes suivante :

1. Créer la base de données

  Lorsque l'on configure GeoPoppy, nous avons tous les outils de créés, il nous suffit de rajouter notre base de données "bagap" d'un simple requête SQL:
  `CREATE DATABASE bagap TEMPLATE template_postgis;`

2. Utiliser le backup de la base de données

  Ensuite, nous récupérons un backup de la base de données sur le serveur central, puis nous l'utilisons pour restaurer la base sur le serveur GeoPoppy.

3. Ajouter les privilèges à l'utilisateur Terrain

  Etant donné que nous avons un utilisateur particulier dans notre base, nous devons lui ajouter ses privilèges à la main, ici nous acceptons qu'il ai tous les privilèges, nous utilisons donc la commande `GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public to terrain;`.
  Si un nouveau schéma est créé, il faut lui donner également les droits sur ce schema en plus des tables: `GRANT ALL PRIVILEGES ON SCHEMA mon_schema TO terrain`.

#### <a id="gp_proj"> A - Préparation des projets</a> `    `[up](#up)
Deux étapes sont nécessaire pour utiliser les outils sur le raspberry :

1. Modifier les coordonnées de la base de données.

  La base de données étant située dans un conteneur sur le Raspberry et non plus sur le serveur principal, il faut redéfinir certains paramètres. Pour ce faire, on ouvre les fichiers de projet QGIS dans un éditeur de texte et on utilise les outils chercher/remplacer sur les champs suivant :

  * host

  * port

  * user

  * password

2. Envois des projet par NextCloud

  Une fois les projets prêt à être utiliser sur le Raspberry, nous les déposons dans les dossiers locaux à l'aide de NextCloud, situé à l'adresse: `black-pearl.local:8000`

Ensuite, on test les interfaces Lizmap pour vérifier que tous c'est bien installé correctement.
#### <a id="gp_sync"> C - Ajout du module de synchronisation</a> `    `[up](#up)

Une dernière étape importante pour l'utilisation des outils avec GeoPoppy, est l'installation du module de synchronisation. Pour ce faire, deux scripts sont présent ici : `ag` . Il suffis de les lancer dans notre base de données pour créer les fonctionnalités de synchronisation.

L'un est à lancer sur le serveur central et créé un nouveau schéma __"sync"__ avec :
* doreplay - *Table*
* sauv_data - *Table*
* conflict - *Vue*
* no_replay - *Vue*
* replay - *Vue*
* ts_excluded - *Vue*

L'autre est à lancer sur le serveur GeoPoppy, il créé également le schéma __"sync"__ avec :
* login - *Table*
* sauv_data - *Table*
* synchro - *Table*

Des triggers sont également créés sur les tables de la base pour enregistrer les changements effectués dans la base.

### <a id="sync"> V) Synchronisation </a>`    `[up](#up)
Pour utiliser la synchronisation de données, nous avons deux interfaces, une connecté au Raspberry, récupérant les données pour les envoyer sur le central, et l'autre sur le central, enregistrant les données provenant du Raspberry. La synchronisation des données se fait en deux temps, on commence par envoyer les données dans
Nous allons détailler ici le fonctionnement de ces applications.

#### <a id="syn_gpp"> A - Interface GeoPoppy </a> `    `[up](#up)
L'interface pour GeoPoppy comprend les trois couches __login__, __sauv_data__ et __synchro__.
![MLD](/ScreenShot/Sync/GeoPoppy/01_sync_couches.png)
* *login* permet la création d'une connexion au serveur. Cette connexion sera appelé plus tard pour diriger les données vers le serveur que l'on souhaite.
* *sauv_data* récupère les données au format json avec les informations utilisateur.
* *synchro* permet d'effectuer la synchronisation en envoyant les données contenues dans sauv_data sur le serveur sélectionné.

Toutes les couches sont ajouté à la table attributaire afin de visualiser les données avant et après lancement de la synchronisation.
![MLD](/ScreenShot/Sync/GeoPoppy/02_sync_attri.png)

Seulement synchro et login sont éditable.

![MLD](/ScreenShot/Sync/GeoPoppy/03_sync_edit.png)

Sur l'interface Lizmap, on a la possibilité de visualiser les données concernant les connexion, les données à synchroniser et les données déjà synchronisées, ainsi que les synchronisations réalisée avec les date de réalisation.

![MLD](/ScreenShot/Sync/GeoPoppy/04_liz_attri.png)

Avant de synchroniser, si nous n'avons pas encore de connexion, il faut en créer une en renseignant un alias  (c'est lui qui sera afficher par la suite), l'adresse du serveur, le port, le nom de l'utilisateur de la base de données, son mot de passe et le nom de la base.

![MLD](/ScreenShot/Sync/GeoPoppy/07_liz_serveur.png)

La synchronisation peut maintenant être lancé, en ajoutant une entité liée à la connexion souhaitée. La date du jour est entrée automatiquement et une valeur booléenne montre la validation de la synchronisation.

![MLD](/ScreenShot/Sync/GeoPoppy/08_liz_synchro.png)
#### <a id="syn_serv"> B - Interface serveur </a> `    `[up](#up)

Du côté de l'application de côté du serveur central, nous avons les couches suivantes:
![MLD](/ScreenShot/Sync/Serveur/01_couches_sync.png)
* *doreplay* est utilisé pour rejouer les données et les insérer dans la base de données.
* *sauv_data* est la table où sont stockées les actions réalisées sur le terrain.
* *ts_excluded*
* *replay* stock les données à rejouer parmi celles provenant du terrain.
* *no_replay* stock les données qu'il ne faut pas rejouer.
* *conflict* stock les données étant en conflit et où une intervention est nécessaire.

Toutes les couches à l'exception de ts_excluded sont utilisées dans les tables attributaire.
![MLD](/ScreenShot/Sync/Serveur/02_table attribu_sync.png)

*doreplay* est ajoutée en édition avec seulement la possibilité d'ajouter une donnée. C'est à l'ajout d'une donnée dans cette table que la synchronisation se lance, une modification n'est donc pas utile.
*conflitct* est également ajouté à l'édition, mais seulement en modification et en suppression pour sélectionner la donnée à synchroniser.

![MLD](/ScreenShot/Sync/Serveur/03_edition_couches.png)

Ainsi, sur Lizmap, nous avons accès dans la fenêtre de table attributaire aux données à insérées, à ne pas insérer, en conflits, le listing de toutes les synchronisation effectuées, et le listing des action effectuées provenant des autres serveur.

![MLD](/ScreenShot/Sync/Serveur/05_liz_attributaire.png)

La finalisation de la synchronisation s'effectue dans l'onglet d'édition en ajoutant une entité à la table *doreplay*. Aucune valeur n'est demandé, seul la date du jour sera ajoutée et une valeur booléenne précisant la réussite ou l’échec de cette synchronisation.

![MLD](/ScreenShot/Sync/Serveur/06_liz_doreplay.png)

Cette dernière image montre l'interface de synchronisation du serveur dans sa globalité.
![MLD](/ScreenShot/Sync/Serveur/07_interface_sync.png)


&nbsp;
&nbsp;

-------------

&nbsp;

Corentin FALCONE / UE INRA Saint-Laurent-de-la-Prée

![MLD](/ScreenShot/INRA_logo_small.jpg)
<p style="text-align:right">Août - 2018</p>
