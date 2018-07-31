
# Bagap - Bordure/Parcelle

Détail de fonctionnement du projet, listing des actions réalisées sur la base de données et fonctionnement des interfaces créées.

## Introduction
Ce projet à pour but le suivi d'occupations et d'entretiens de parcelles et de bordures.

Une observation se fait sur une parcelle et une bordure à une date donnée décrite lors d'une session.
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

***
### <a id="sql">I) SQL</a>

Les fichier *__update_keys.sql__*, *__view.sql__*, *__function.sql__* et *__trigger_maj_bordure.sql__* listent les modifications apportées à la base de données.

* <a id="base"> **update_keys.sql** </a> réorganise la base de données en ajoutant, modifiant et supprimant des colonnes et des contraintes sur les tables.
  * Ajout des champs de géométrie
  * Modification des clé primaires et étrangères
  * Mise à jour des données en fonction des nouvelles contraintes
  * Ajout de la table histo_fusion listant les entités à fusionner
  * Ajout d'un utilisateur "Terrain" pour une modification des observation seulement sur la session courante.


* <a id="view"> **view.sql**</a> créé les vues utilisées pour les interfaces.
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


* <a id="func"> **function.sql** </a> cré les fonctions de calcul et d'insertion.
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
### <a id="field">II)	Interface terrain</a>
[UP](#up)

Cette interface est vouées à être utilisée sur le terrain.

Les contraintes pour cet affichage sont :
* Ajouter des observations dans le cas où une session est présente
* Modifier seulement les observations de la session en cours
* Afficher les observations de la dernière session
* Suivre l'avancement du parcours sur le terrain

  #### <a id="pqgisF"> A - Projet QGIS </a>
[UP](#up)

Les couches contenus dans ce projet sont les suivantes :

<table>
  <tr>
    <td rowspan=11>
      ![MLD](/ScreenShot/Field/01_liste_couches.png)
    </td>
    <td>
      **<span style='color:#96CA2D'>lisiere :</span>** Affichage géographique des lisières.    
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#046380'>v_observation_bordure :</span>** Affichage géographique des observation de bordures de la session courante.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#046380'>v_observation_fusion :</span>** Affichage géographique des observation de surfaces fusionnées.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#046380'>v_observation_surface:</span>** Affichage géographique des observation de surfaces courante ou de la dernière session.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#E6E2AF'>mv_zone: </span>** Affichage géographique des trois zones de suivi.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#01B0F0'>utilisation_sol :</span>** Couche donnant les valeurs relationnelles des types d'utilisation et d'occupation du sol.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#01B0F0'>etat_surface:</span>** Couche donnant les valeurs relationnelles des types d'état d'une surface.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#BD8D46'>session :</span>** Couche donnant l'information sur l'état des sessions. Seulement les deux dernières sont prises en compte.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#8E3557'>v_mod_session :</span>** Couche donnant les valeurs sous forme de libellé pour l'affichage des sessions dans la table attributaire. Cette couche est jointe à la couche session.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#01B0F0'>observateur :</span>** Couche donnant les valeurs relationnelles des observateurs d'une session.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#01B0F0'>etat_session :</span>** Couche donnant les valeurs relationnelles des états d'une session.
    </td>
  </tr>
</table>

  * <span style='color:#96CA2D'> Entités géographiques présentes pour la reconnaissance du terrain.</span>

  * <span style='color:#046380'>  Entités présentes pour l'ajout d'information par modification de la base de données de façon géographique.</span>

  * <span style='color:#E6E2AF'>  Entités présentes pour zoomer rapidement sur les entités voulues.</span>

  * <span style='color:#01B0F0'>  Entités présentes pour afficher les valeurs relationnelles sous forme de libellé dans les popups et formulaires d'édition.</span>

  * <span style='color:#BD8D46'>  Entités présentes pour donner des informations supplémentaires et non géographiques.</span>

  * <span style='color:#8E3557'>  Entités présentes pour afficher les valeurs relationnelles sous forme de libellé dans la table attributaire. </span>

###### Paramétrage des champs
L'affichage dans lizmap utilise les paramètres de QGIS. Nous allons donc définir les champs que nous voulons voir dans les popups et les formulaires d'édition. Pour ce faire, nous allons dans les ** *propriétés de la couche* ** puis dans l'onglet ** *Champs * **
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

  #### <a id="plizmapF"> B - Paramètres Lizmap </a>
  [UP](#up)

Cette interface doit permettre la modification des observations sur les parcelles et sur les bordures. Il doit aussi rendre possible la modification de l'état de la session une fois que celle-ci est finie.

###### Paramétrage des actions
* Edition

Nous ajoutons les couches éditable dans l'onglet ** *'Édition des couches'* ** .
Pour chacune des couches, nous cochons l'option ** *'Modifier les attributs'* ** ainsi que ** *'Supprimer'* ** , excepté pour la couche session.

   ![MLD](/ScreenShot/Field/09_param_edition.png)

* Table attributaire

Ajouter les couches dans l'onglet ** *'Table attributaire'* ** permet d'afficher les données des couches dans un tableau sur l'interface. C'est aussi en les ajoutant dans cet onglet, que l'on peut utiliser le trie par localisation de la couche, ainsi que les relations parent/enfant qui filtrent les enfants en fonction de l'entité parent.

Ici, nous voulons simplement visualiser les données de la table session, mais nous ajoutons aussi la table mv_zone en cochant l'option ** *'Masquer la couche dans la liste'* ** puisque nous n'avons pas besoin de voir les données, mais nous utilisons la localisation sur la couche.


   ![MLD](/ScreenShot/Field/10_param_attributaire.png)

* Localisation par couche

La localisation par couche permet de filtrer les données d'une couche en fonction des attributs spécifiés. Si l'entité est géographique, il est possible de zoomer dessus. Nous l'utilisons ici pour centrer la carte sur la zone sur laquelle nous voulons enregistrer les observations.

   ![MLD](/ScreenShot/Field/11_param_locate_zone.png)

###### <a id="affich"> Paramétrage de l'affichage </a>

La configuration de l'affichage se fait dans l'onglet ** *'Couches'* ** du plugin Lizmap dans la partie ** *'Popup'* ** de la couche sélectionnée. En sélectionnant 'lizmap' comme source, il est possible de modifier les informations à afficher par la popup avec un balisage HTML. Cela est utile pour embellir l'affichage, ou pour ne montrer que certains champs.

Ici nous souhaitons avoir une vision simplifier des champs des couches d'observation. Nous utilisons un tableau avec des fonds de couleur intercalés une fois sur deux et les valeurs booléennes sont en majuscule.

* Bordures


   ![MLD](/ScreenShot/Field/12_param_bordure_config.png)
*  Parcelles 'fusion'


   ![MLD](/ScreenShot/Field/13_param_fusion_config.png)

* Parcelles


   ![MLD](/ScreenShot/Field/14_param_surface_config.png)


  #### <a id="usesF"> C - Utilisations </a>

Avec cette interface, nous pouvons nous diriger sur le terrain et saisir simplement les données concernant les entretiens des bordures et l'état des parcelles.

   ![MLD](/ScreenShot/Field/15_interface_global.png)


***
### <a id="desktop">III) Interface bureau</a>
[UP](#up)

Cette interface est vouées à être utilisée au bureau.

Les contraintes pour cet affichage sont :
* Visualiser les observations de toutes les sessions
* Modifier toutes les observations
* Modifier toutes les tables paramètres
* Avoir une symbologie par état de surface et occupation du sol
* Avoir une symbologie par type d'entretien de bordure.
* Pouvoir fusionner des parcelles entre elles
* Visualiser la totalité des données

  #### <a id="pqgisD"> A - Projet QGIS</a>
[UP](#up)

<table>
  <tr>
    <td rowspan=23>
      ![MLD](/ScreenShot/Desktop/01_liste_couches.png)
    </td>
    <td>
      **<span style='color:#E6E2AF'>histo_fusion :</span>** Affichage ponctuel des parcelles fusionnées.    
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#96CA2D'>lisiere :</span>** Affichage géographique des lisières.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#046380'>Strate herbacée :</span>** Affichage géographique des observations de bordures dont les entretiens correspondent à la partie herbacée.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#046380'>Strate arbustive :</span>** Affichage géographique des observations de bordures dont les entretiens correspondent à la partie arbustive.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#046380'>Strate arborée:</span>** Affichage géographique des observations de bordures dont les entretiens correspondent à la partie arborée.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#046380'>Haie: </span>** Affichage géographique des observations de bordures dont les entretiens correspondent à la partie haie.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#046380'>Autre :</span>** Affichage géographique des observations de bordures n'ayant pas d'entretiens observé.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#046380'>Surface ocs:</span>** Affichage géographique des observations de surfaces catégorisé suivant l'occupation du sol.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#046380'>Surface etats :</span>** Affichage géographique des observations de surfaces catégorisé suivant l'état.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#96CA2D'>bordure :</span>** Affichage des bordures afin de les modifier ou d'en ajouter.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#96CA2D'>surface :</span>** Affichage des surfaces dans le but de les modifier ou d'en ajouter.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#E6E2AF'>mv_zone :</span>** Affichage géographique des trois zones de suivi.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#BD8D46'>session_old :</span>** Couche donnant l'information sur l'état des sessions. Seulement les deux dernières sont prises en compte.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#01B0F0'>observateur :</span>** Couche donnant les valeurs relationnelles des observateurs d'une session.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#8E3557'>v_mod_session :</span>** Couche donnant les valeurs sous forme de libellé pour l'affichage des sessions dans la table attributaire. Cette couche est jointe à la couche session.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#01B0F0'>etat_session :</span>** Couche donnant les valeurs relationnelles des états d'une session.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#BD8D46'>observation_bordure :</span>** Couche donnant les informations des observations des bordure pour chaque session.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#8E3557'>v_mod_bordure :</span>** Couche donnant les valeurs relationnelles des observations de bordure.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#8E3557'>v_mod_observation_bordure :</span>** Couche donnant les valeurs relationnelles des observations de bordure.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#BD8D46'>observation_surface:</span>** Couche donnant les informations des observations des parcelles pour chaque session.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#01B0F0'>etat_surface :</span>** Couche donnant les valeurs relationnelles des types d'état d'une surface.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#01B0F0'>utilisation_sol :</span>** Couche donnant les valeurs relationnelles des types d'utilisation et d'occupation du sol.
    </td>
  </tr>
  <tr>
    <td>
      **<span style='color:#8E3557'>v_mod_observation_surface :</span>** Couche donnant les valeurs relationnelles des observations de parcelle.
    </td>
  </tr>
</table>

Pour cet interface, nous utilisons des liens parent/enfant. Nous l'utilisons d'une part pour effectuer des tris par session et d'autre part pour regrouper les observations par parcelles et visualiser son avancement.

![MLD](/ScreenShot/Desktop/02_relation_qgis.png)

Les relations ainsi créées concernent les couches d'observation. Chaque catégorie d'observation de bordure est reliée à la couche session, ce qui va rendre dynamique l'affichage des observations sur la carte en fonction des sessions. Il en est de même pour les deux symbologies des observations de parcelles.
De plus, les couche ** *'observation_bordure'* ** et ** *'observation_surface'* ** sont liées respectivement aux couches ** *'bordure'* ** et ** *'surface'* ** .

Les couches ** *'Strate herbacée'* ** , ** *'Strate arbustive'* ** , ** *'Strate arborée'* ** , ** *'Haie'* ** et ** *'Autre'* ** proviennent de la vue ** *'v_observation_bordure'* ** et sont filtrées dans QGIS en fonction de la valeur des champs provenant de la catégorie respective.

Les couches ** *'Surface ocs'* ** et ** *'Surface etats'* ** proviennent de la vue ** *'v_observation_surface'* ** .

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

![MLD](/ScreenShot/Desktop/08_obs_bord_style herba.png)

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


  #### <a id="plizmapD"> B - Paramètres Lizmap </a>
[UP](#up)

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

  #### <a id="usesD"> C - Utilisations </a>

Avec cette interface, nous pouvons manipuler nos données et corriger les données provenant du terrain. Nous avons un contrôle et un accès total aux données de la base.

![MLD](/ScreenShot/Desktop/16_interface_desktop.png)
