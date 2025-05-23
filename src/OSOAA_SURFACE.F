C******************************************************************************
C* FICHIER: OSOAA_SURFACE.F
C*
C*------------------------------------------------------------------------ 
C* OSOAA Licence
C*   Copyright (c) 2015, Universit� Pierre et Marie Curie - Paris 6
C*                       (renamed as Sorbonne Universit� since 2018)
C*                       and Centre National d'Etudes Spatiales (CNES)
C* 
C*   This program is free software: you can redistribute it and/or modify
C*   it under the terms of the GNU General Public License as published by
C*   the Free Software Foundation, either version 2 of the License, or
C*   (at your option) any later version.
C* 
C*   This program is distributed in the hope that it will be useful,
C*   but WITHOUT ANY WARRANTY; without even the implied warranty of
C*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
C*   See the GNU General Public License for more details.
C* 
C*   You should have received a copy of the GNU General Public License
C*   along with this program.  If not, see <http://www.gnu.org/licenses/>.
C*------------------------------------------------------------------------ 
C* 
C*
C* PROJET: Ordres Successifs Oc�an Atmosph�re  - Avanc�
C*         Ocean Successive Orders with Atmosphere - Advanced
C*
C* ROLE: Ce module g�n�re les matrices de r�flexion et de transmission
C*       pour l'interface air / mer
C*
C* AUTEURS:  
C*
C*   Fondement algorithmique pour le Glitter :
C*      - Laboratoire d'Optique Atmosph�rique (LOA, Villeneuve d'Ascq) 
C*          Jean-Luc Deuz�, Maurice Herman, Richard Santer
C*        ==> code des Ordres Successifs de Diffusion 
C*            (version atmosph�rique et glitter).
C*      - Communication & Syst�mes (CS, Toulouse) pour le compte du CNES
C*          Bruno Lafrance
C*          ==> code SOS (version industrialis�e du code des OS du LOA).
C*
C*   Code OSOAA : Sp�cification de l'interface air/mer agit�e, impl�mentation 
C*      - Communication & Systemes (CS, Toulouse)
C*          Bruno Lafrance
C*
C*
C* ROUTINES COUVERTES PAR LE FICHIER : 
C*   - OSOAA_SURFACE
C*   - OSOAA_NOM_FIC_INTERFACE
C*
C*
C* MOD:VERSION:1.0: 02/04/2015: Initial version of the OSOAA code
C* MOD:VERSION:1.1: 15/06/2015: 
C*         - All comments for log files are now in english
C*         - Changing the way of reading the formatted files (Angles, ...)
C*           to be compatible with the compiler gfortran.
C* MOD:VERSION:1.2: 25/03/2016: 
C*         - Removal of screen information when BRDF/BPDF file 
C*           has already been calculated.  
C*         - Change of reading the string FICANGLES_USER in file FICANGLES
C*           (for gfortran compilation - linux system)                        
C* MOD:VERSION:1.3: 03/11/2016:
C*     Changes to be compliant with a f77 compilation
C*         - CALL FLUSH() changed to CALL FLUSH(6)
C*         - Change a variable type to read the file FICANGLES                       
C* MOD:VERSION:1.4: 09/01/2024:                   
C*     - Deleting of a few commas after a READ function to avoid warnings during compilation.
C*                   
C*   
C******************************************************************************

C----------------------------------------------------------------------------
C D�finition des constantes  
C---------------------------------------------------------------------------- 
C Constantes utilis�es : 
C    
C    CTE_LENDIR : Longueur des noms de r�pertoires. 
C    CTE_LENFIC1 : Longueur des noms de fichiers sans arborescence.
C    CTE_LENFIC2 : Longueur des noms de fichiers avec arborescence.
C    CTE_OS_NBMU_MAX  : Nombre maximal d'angles de Gauss positifs 
C                       pour les calculs de luminance
C
C Constantes sp�cifiques :
C    INCTE_IDLOG_SURFACE : ID du ficher Trace de la routine
C    INCTE_PI : Valeur de PI (calcul� par la machine)
C    LENLINE  : Longueur maximale d'une ligne de donn�es lue dans un fichier
C----------------------------------------------------------------------------
#include "OSOAA.h"
#define INCTE_IDLOG_SURFACE 99
#define INCTE_PI DACOS(-1.D+00)
#define LENLINE 1000

C==============================================================================
C PROCEDURE: OSOAA_SURFACE
C ==========
C      Programme de g�n�ration des matrices de r�flexion et de transmission
C      pour l'interface air - mer agit�e:
C		- Matrice de r�flexion air / air.
C		- Matrice de transmission air / eau.
C		- Matrice de r�flexion eau / eau.
C		- Matrice de transmission eau / air .
C
C Description des param�tres   
C --------------------------
C
C     DIRS (CHAR*CTE_LENDIR)  (E) : Nom du r�pertoire de stockage des fichiers SURFACE
C                                   r�sultats (chemin complet).    	
C
C     FICANGLES (CHAR*CTE_LENFIC2)  (E) :  Nom complet du fichier des angles utilis�s 
C                                          pour les calculs de luminance et BRDF
C                 			   (r�pertoire + nom fichier + extension)
C
C     SEA_IND	(double)    	    (E) : Indice de r�fraction de l'eau de mer.
C
C     WIND	(double)    	    (E) : Vitesse du vent (m/s).
C
C     FICSURF_LOG (CHAR*CTE_LENFIC2)  (E) : 
C                                   Nom complet du fichier Trace de la routine OSOAA_SURFACE
C                                   (r�pertoire + nom fichier + extension)
C                                   Si ce fichier n'a pas �t� d�fini par l'utilisateur,
C                                   ce nom en entr�e est 'NO_LOG_FILE',
C				    et le fichier Trace n'est pas cr��.
C    
C     IER (I4)        		    (S) : indice d'erreur : 0 si pas d'erreur, -1 sinon.
C   
C
C R�sultat fourni par la proc�dure  
C --------------------------------
C
C    Les quatre fichiers d'interface air / mer agit�e:
C      - r�flexion Air / Air    : RAA-IND-WIND-MUnb-SZAnn.nnn-TSZAnn.nnn-NomFicUser
C      - transmission Air / Mer : TAW-IND-WIND-MUnb-SZAnn.nnn-TSZAnn.nnn-NomFicUser
C      - r�flexion Mer / Mer    : RWW-IND-WIND-MUnb-SZAnn.nnn-TSZAnn.nnn-NomFicUser
C      - transmission Mer / Air : TWA-IND-WIND-MUnb-SZAnn.nnn-TSZAnn.nnn-NomFicUser
C
C       avec 
C      	* IND l'indice de r�fraction air/mer au format F5.3 (ex : 1.500) 
C      	* WIND la vitesse du vent au format F4.1 (ex : 12.5) 
C      	* MUnb le nombre d'angles de Gauss (ex : MU40)
C      	* SZAnn.nnn l'angle z�nithal solaire dans l'air F6.3 (ex : 30.000)
C      	* TSZAnn.nnn l'angle z�nithal solaire dans la mer F6.3 (ex : 21.909) 
C      	* NomFicUser le nom du fichier utilisateur (sans arborescence) (ex: MyAngles)
C
C
C    Un fichier Trace optionnel.
C
C 
C 
C Description des fichiers utilis�s	 
C ---------------------------------
C
C    Fichier FICANGLES:
C      ==>   Contenu du fichier des angles (ID = 10)
C            Fichier ascii format�, cr�� par OSOAA_ANGLES.
C            Il contient l'information sur les angles � utiliser 
C            et sur les ordres des d�veloppements adapt�s : 
C		NB_TOTAL_ANGLES :    nb d'angles total � utiliser
C               NB_GAUSS_ANGLES :    nb d'angles de Gauss
C               ANGLES_USERFILE :    Nom du fichier des angles utilisateur
C	        SOLAR ZENITH ANGLE : Angle z�nithal solaire (degr�s)
C		INTERNAL_IMUS :      Num�ro d'indice de table correspondant
C	        TRANSMITTED SOLAR ZENITH ANGLE IN WATER : Angle z�nithal solaire (degr�s)
C                                                         transmis dans la mer (plate)
C		INTERNAL_IMUSW :     Num�ro d'indice de table correspondant
C               INTERNAL_OS_NB :     Ordre des d�veloppements des fonctions de phase 
C				     en Polyn�mes de Legendre � utiliser.
C                                    Ordre maximal � utiliser pour le d�veloppement en
C                                    s�ries de Fourier des calculs de luminance et
C				     des matrices d'interface.
C               INTERNAL_OS_NS :     Ordre maximal � utiliser pour le d�veloppement en
C                                    polyn�mes de Legendre des �l�ments de la matrice de 
C                                    Fresnel.
C               INTERNAL_OS_NM :     Ordre maximal du d�veloppement en s�ries de Fourier.  
C                                    de la fonction G des calculs de matrice d'interface.
C               INDEX COS_ANGLE WEIGHT OUTPUT: lignes donnant le num�ro d'angle, son cosinus
C                                              et son poids, s'il est donn� en sortie 
C                                              "utilisateur" au format I4,1X,2D21.14,1X,I4
C         
C        
C
C    Fichier trace : identifiant = IDLOG = INCTE_IDLOG_SURFACE 
C      ==>   contient des informations sur les �tapes de calculs
C
C
C
C    Fichiers r�sultats d'interface air / mer agit�e:
C      - r�flexion Air / Air    : RAA-IND-WIND-MUnb-SZAnn.nnn-TSZAnn.nnn-NomFicUser
C      - transmission Air / Mer : TAW-IND-WIND-MUnb-SZAnn.nnn-TSZAnn.nnn-NomFicUser
C      - r�flexion Mer / Mer    : RWW-IND-WIND-MUnb-SZAnn.nnn-TSZAnn.nnn-NomFicUser
C      - transmission Mer / Air : TWA-IND-WIND-MUnb-SZAnn.nnn-TSZAnn.nnn-NomFicUser
C
C       avec 
C      	* IND l'indice de r�fraction air/mer au format F5.3 (ex : 1.500) 
C      	* WIND la vitesse du vent au format F4.1 (ex : 12.5) 
C      	* MUnb le nombre d'angles de Gauss (ex : MU40)
C      	* SZAnn.nnn l'angle z�nithal solaire dans l'air F6.3 (ex : 30.000)
C      	* TSZAnn.nnn l'angle z�nithal solaire dans la mer F6.3 (ex : 21.909) 
C      	* NomFicUser le nom du fichier utilisateur (sans arborescence) (ex: MyAngles)
C
C
C       Chacun des ces fichiers est un fichier binaire non format�
C       qui contient la matrice d'interface d�compos�e en s�rie de Fourier.
C        --> Pour chaque ordre IS de la d�composition en s�rie de Fourier (IS = 0 � OS_NB),
C            le fichier contient l'enregistrement des �l�ments Pij de la matrice,
C            limit� aux angles utiles : 
C              P11(LUM_NBMU,LUM_NBMU) (r�el),
C              P12(LUM_NBMU,LUM_NBMU) (r�el),
C              P13(LUM_NBMU,LUM_NBMU) (r�el),
C              P21(LUM_NBMU,LUM_NBMU) (r�el),
C              P22(LUM_NBMU,LUM_NBMU) (r�el),
C              P23(LUM_NBMU,LUM_NBMU) (r�el),
C              P31(LUM_NBMU,LUM_NBMU) (r�el),
C              P32(LUM_NBMU,LUM_NBMU) (r�el),
C              P33(LUM_NBMU,LUM_NBMU) (r�el)
C
C
C Common utilis�:
C --------------
C  Aucun
C
C Cas d'erreur : 
C ------------
C     - Erreur dans un sous-programme
C     - Erreur � l'ouverture, lecture et �criture du fichier Trace 
C       et des fichiers E/S :  fichier des angles et fichiers r�sultats.
C     - Erreur sur la longueur du nom du r�pertoire de stockage des fichiers 
C       de matrices d'interface.
C
C     Affichage d'un message � l'�cran, la routine interrompt ses calculs et 
C     retour du status -1 au programme appelant
C
C
C  Sous programmes utilis�s:
C --------------------------
C  Ce programme fait appel aux routines:
C      - OSOAA_NOM_FIC_INTERFACE
C      - OSOAA_SURFACE_CASE
C
C==============================================================================

      SUBROUTINE OSOAA_SURFACE(DIRS, FICANGLES, SEA_IND, WIND, 
     &			       FICSURF_LOG, IER)

      IMPLICIT NONE

C Constantes 
C -----------------            
      INTEGER*2 IDLOG			! Num�ro identifiant du fichier Trace	    
      PARAMETER(IDLOG=INCTE_IDLOG_SURFACE)
            
C* D�finition des variables                         
C*-----------------------------------------------------------------
      DOUBLE PRECISION SEA_IND ! (E) Indice de r�fraction de la mer 
      			       ! pour la longueur d'onde de simulation de la luminance. 

      DOUBLE PRECISION WIND    ! (E)  Vitesse du vent (m/s).

      DOUBLE PRECISION RMU(-CTE_OS_NBMU_MAX:CTE_OS_NBMU_MAX)  
                                             !Cosinus des angles de Gauss (et utilisateur).
      DOUBLE PRECISION CHR(-CTE_OS_NBMU_MAX:CTE_OS_NBMU_MAX)  
                                             !Poids des angles de Gauss.	
        
      DOUBLE PRECISION TETAS   ! Angle z�nithal solaire en degr�s (0 < tetas < 90).
      			       ! (angle compl�mentaire : mus= -cos(tetas))      
				
      DOUBLE PRECISION TETASW  ! Angle z�nithal solaire en degr�s (0 < tetas < 90) 
      			       ! transmis dans mer plate.
      			       ! (angle compl�mentaire : mus= -cos(tetas))     
      
      INTEGER*4 IER            ! (S) Code d'erreur =0 si pas d'erreur, =-1 sinon
      
      INTEGER*4 NBMU_GAUSS     ! Nombre d'angles de Gauss utilis�s       
      INTEGER*4 LUM_NBMU       ! Nombre d'angles effectifs des simulations
      INTEGER*4 LDIRS	       ! longueur de la chaine de caract�re DIRS.
      INTEGER*4 LFICS	       ! longueur de la chaine de caract�re FICS.    
      INTEGER*4 J	       ! Indice de tableau                    
      INTEGER*4 OS_NB 	       ! Ordre des d�veloppements des fonctions de phase 
			       ! en Polyn�mes de Legendre, des matrices d'interface et
			       ! des champs de luminance.
      INTEGER*4 OS_NS          ! Ordre maximal du d�veloppement en polyn�mes de Legendre   
			       ! des �l�ments de la matrice de Fresnel.
      INTEGER*4 OS_NM          ! Ordre maximal du d�veloppement en s�ries de Fourier de la  
			       ! fonction G des calculs de matrice d'interface.
      INTEGER*4 IMUS           ! Indice de l'angle z�nithal solaire dans la table des angles
      INTEGER*4 IMUSW          ! Indice de l'angle z�nithal solaire transmis de la table 
      			       ! des angles
  
      INTEGER*4 IFIN           ! nb de caract�res significatifs d'une chaine  

      INTEGER*4 NVAL 	       ! Integer pour la lecture de fichier ANGLES
      
      CHARACTER*CTE_LENDIR DIRS		! (E)  chemin d'acc�s aux fichiers SURFACE r�sultats
      CHARACTER*CTE_LENFIC1 FICS   	! Nom du fichier SURFACE (sans arborescence).
      CHARACTER*CTE_LENFIC2 FICANGLES   ! (E)  Chemin et nom du fichier des angles utilis�s 
                                        ! pour les calculs de luminance      
      CHARACTER*CTE_LENFIC2 FICANGLES_USER  ! Chemin et nom du fichier des angles 
      					    ! "utilisateurs" 
      CHARACTER*CTE_LENFIC2 FICSURF_LOG ! (E)   Nom du fichier trace 
      
      ! Nom complet des fichiers de matrice d'interface :
      CHARACTER*CTE_LENFIC2 FICRAA 	! r�flexion air / air.
      CHARACTER*CTE_LENFIC2 FICTAW 	! transmission air / eau.
      CHARACTER*CTE_LENFIC2 FICRWW 	! r�flexion eau / eau.
      CHARACTER*CTE_LENFIC2 FICTWA 	! transmission eau / air .
      
      CHARACTER*1000 CVAL      ! Chaine de caract�res pour la lecture de valeurs inutilis�es

      CHARACTER*LENLINE LIGNE_TEXTE	!Ligne de caract�res pour d�codage de param�tres
      
      LOGICAL TRACE            ! = vrai si �criture dans le fichier trace      
      LOGICAL EX	       ! V�rifie l'existence d'un fichier.
      LOGICAL ADD_TETAS	       ! =vrai s'il faut ajouter TETAS au nom du fichier
      LOGICAL ADD_TETASW       ! =vrai s'il faut ajouter TETASW au nom du fichier


C*-------------
C* Traitements                        
C*-------------

C* Initialisation                     
C*-----------------------------------------------------------------
      IER=0
        
C* Ouverture du fichier Trace 
C------------------------------------------------------
      IF (FICSURF_LOG.EQ.'NO_LOG_FILE') THEN
	 TRACE=.FALSE.
      ELSE
         TRACE=.TRUE.
	 OPEN(IDLOG,FILE=FICSURF_LOG,ERR=2000)
      ENDIF	 	

C* Calcul de la longueur de la chaine de caract�res pour le nom du r�pertoire r�sultat
         LDIRS = INDEX(DIRS,' ')
         LDIRS = LDIRS - 1
	 
	 IF((LDIRS.LE.0).OR.(LDIRS.GT.CTE_LENDIR)) GOTO 1900
	 
	 IF (TRACE) THEN
	    WRITE(IDLOG,*,ERR=2010) "MATRICES REPOSITORY DIRECTORY :"
	    WRITE(IDLOG,*,ERR=2010) "*******************************"
	    WRITE(IDLOG,*,ERR=2010) " "
	    WRITE(IDLOG,*,ERR=2010) DIRS
            WRITE(IDLOG,*,ERR=2010) " "
	 ENDIF
	 
	 
C* Lecture des tables d'angles et de poids utiles aux simulations
C* -----------------------------------------------------------------     
      OPEN(UNIT=10,FILE=FICANGLES,STATUS='OLD',ERR=2100)

      READ(10,'(a)',ERR=2101) LIGNE_TEXTE
      IFIN=INDEX(LIGNE_TEXTE,':')
      READ(LIGNE_TEXTE(IFIN+1:LENLINE),*) LUM_NBMU
      
      READ(10,'(a)',ERR=2101) LIGNE_TEXTE
      IFIN=INDEX(LIGNE_TEXTE,':')
      READ(LIGNE_TEXTE(IFIN+1:LENLINE),*) NBMU_GAUSS
      
      READ(10,'(a)',ERR=2101) LIGNE_TEXTE
      IFIN=INDEX(LIGNE_TEXTE,':')
      FICANGLES_USER=LIGNE_TEXTE(IFIN+1:LENLINE)
      IFIN=INDEX(FICANGLES,' ')
      FICANGLES_USER=FICANGLES_USER(1:IFIN)
      
      READ(10,'(a)',ERR=2101) LIGNE_TEXTE
      IFIN=INDEX(LIGNE_TEXTE,':')
      READ(LIGNE_TEXTE(IFIN+1:LENLINE),*) TETAS
     
      READ(10,'(a)',ERR=2101) LIGNE_TEXTE
      IFIN=INDEX(LIGNE_TEXTE,':')
      READ(LIGNE_TEXTE(IFIN+1:LENLINE),*) IMUS
      
      READ(10,'(a)',ERR=2101) LIGNE_TEXTE
      IFIN=INDEX(LIGNE_TEXTE,':')
      READ(LIGNE_TEXTE(IFIN+1:LENLINE),*) TETASW
      
      READ(10,'(a)',ERR=2101) LIGNE_TEXTE
      IFIN=INDEX(LIGNE_TEXTE,':')
      READ(LIGNE_TEXTE(IFIN+1:LENLINE),*) IMUSW
      
      READ(10,'(a)',ERR=2101) LIGNE_TEXTE
      IFIN=INDEX(LIGNE_TEXTE,':')
      READ(LIGNE_TEXTE(IFIN+1:LENLINE),*) OS_NB
      
      READ(10,'(a)',ERR=2101) LIGNE_TEXTE
      IFIN=INDEX(LIGNE_TEXTE,':')
      READ(LIGNE_TEXTE(IFIN+1:LENLINE),*) OS_NS
      
      READ(10,'(a)',ERR=2101) LIGNE_TEXTE
      IFIN=INDEX(LIGNE_TEXTE,':')
      READ(LIGNE_TEXTE(IFIN+1:LENLINE),*) OS_NM
      
      READ(10,*,ERR=2101) CVAL
      
      DO J=1,LUM_NBMU
         READ(10,*,ERR=2101) NVAL, RMU(J), CHR(J), NVAL
      ENDDO 
      
      CLOSE(10)
      

      DO J=1,LUM_NBMU
         RMU(-J) = -RMU(J)
	 CHR(-J) =  CHR(J)
      ENDDO 

C* D�termination du besoin d'extension par TETAS et/ou TETASW
C* ==> Si pas angle de gauss ni angle nul (toujours d�fini dans la liste des angles)
C  ----------------------------------------------------------   
      IF ((CHR(IMUS).EQ.0.D+00).AND.(TETAS.NE.0.D+00)) THEN
          ADD_TETAS=.TRUE.
      ELSE
          ADD_TETAS=.FALSE.
      ENDIF 	
        
      IF ((CHR(IMUSW).EQ.0.D+00).AND.(TETASW.NE.0.D+00)) THEN
          ADD_TETASW=.TRUE.
      ELSE
          ADD_TETASW=.FALSE.
      ENDIF 	  
      
C* Trace
C  ----------------------------------------------------------          
      IF (TRACE) THEN
         WRITE(IDLOG,*,ERR=2010) "USED ANGLES"
	 WRITE(IDLOG,*,ERR=2010) "************"
	 WRITE(IDLOG,*,ERR=2010) " "
	 WRITE(IDLOG,*,ERR=2010) "Total number of angles : ",
     &   LUM_NBMU
	 WRITE(IDLOG,*,ERR=2010) "Number of Gauss angles : ",
     &   NBMU_GAUSS
	 WRITE(IDLOG,*,ERR=2010) " "
	 WRITE(IDLOG,*,ERR=2010) "Solar zenith angle : ", TETAS
	 IF (ADD_TETAS) THEN
	     WRITE(IDLOG,*,ERR=2010) 
     &       "  --> Must be added to the filename"
	 ELSE
	     WRITE(IDLOG,*,ERR=2010)
     &       "  --> Gauss angle or null value"
	 ENDIF
	 WRITE(IDLOG,*,ERR=2010) "Solar zenith angle in the sea: ",
     &	   TETASW
	 IF (ADD_TETASW) THEN
	     WRITE(IDLOG,*,ERR=2010)
     &       "  --> Must be added to the filename"
	 ELSE
	     WRITE(IDLOG,*,ERR=2010)
     &       "  --> Gauss angle or null value"
	 ENDIF
	 WRITE (IDLOG,*,ERR=2010) " "
         IF (FICANGLES_USER.NE.'NO_USER_ANGLES') THEN
	     WRITE(IDLOG,*,ERR=2010)  
     &	       "A file of user's angles is used :", FICANGLES_USER
     	     WRITE(IDLOG,*,ERR=2010) "Number of user's angles :",
     &         (LUM_NBMU-NBMU_GAUSS)
	 ELSE
	     WRITE(IDLOG,*,ERR=2010)  
     &	       "No file of user's angles"
	 ENDIF
         WRITE (IDLOG,*,ERR=2010) " " 
	 WRITE (IDLOG,*,ERR=2010) "Ordre max NB ", OS_NB
	 WRITE (IDLOG,*,ERR=2010) "Ordre max NS ", OS_NS
	 WRITE (IDLOG,*,ERR=2010) "Ordre max NM ", OS_NM
	 WRITE (IDLOG,*,ERR=2010) " " 
	 WRITE (IDLOG,*,err=2010) "List of used angles :"
	 WRITE (IDLOG,*,err=2010) 
     &   "   Index, mu, angle (degrees), weigth"
	 DO 1000 J=-LUM_NBMU,LUM_NBMU
	    IF (J.EQ.0) GOTO 1000
	    IF (J.LT.0) THEN 
	        WRITE(IDLOG,222,ERR=2010) J, RMU(J),
     &	              -DACOS(-RMU(J))*180./INCTE_PI, CHR(J)
            ELSE
	        WRITE(IDLOG,222,ERR=2010) J, RMU(J),
     &	              DACOS(RMU(J))*180./INCTE_PI, CHR(J)
	    ENDIF
1000     CONTINUE	
	 WRITE (IDLOG,*,ERR=2010) " " 
	 WRITE (IDLOG,*,ERR=2010) " "  	
      ENDIF !Fichier Trace	 



C*-------------
C* Traitements                        
C*-------------

      WRITE(6,*) 'Surface matrices repertory : ', DIRS(1:LDIRS)
      CALL FLUSH(6)	!Force l'envoie du message � l'�cran

C =====================================================================
C* Cas de la matrice de r�flexion air --> air
C =====================================================================
            

C* Constitution du nom du fichier RAA
C  --------------------------------------   
      CALL OSOAA_NOM_FIC_INTERFACE("RAA",NBMU_GAUSS,OS_NB,
     &                              TETAS,ADD_TETAS,TETASW,ADD_TETASW,
     &                              FICANGLES_USER,SEA_IND,WIND,FICS)
     	
      FICRAA = DIRS(1:LDIRS)//'/'//FICS
      LFICS=INDEX(FICRAA,' ')-1
	 
      IF (TRACE) THEN
	  WRITE (IDLOG,*,ERR=2010) 
     &               "\n\n\n   --> RAA Matrix file : " ,
     &               FICRAA(1:LFICS)
      ENDIF !Fichier Trace  
	 
C* Si le fichier RAA existe d�j�, la routine n'est pas lanc�e
C  ---------------------------------------------------------------     
      INQUIRE(FILE=FICRAA(1:LFICS),EXIST=EX)
	  
      IF( EX) THEN  
	    
	  IF (TRACE) THEN
	      WRITE (IDLOG,*,ERR=2010) 
     &               "       --> RAA file has already been calculated"
	  ENDIF !Fichier Trace  
	    
      ELSE   
      
C* Calcul du fichier RAA
C  ------------------------- 
          WRITE(6,*) 'Matrix RAA : ', FICRAA(LDIRS+2:LFICS)
          WRITE(6,*) '-- RAA Matrix file is being calculated' 
	  CALL FLUSH(6)	!Force l'envoie du message � l'�cran
	     
	  IF (TRACE) THEN
	     WRITE (IDLOG,*,ERR=2010) 
     &               "--Calculation of RAA Matrix file : " 
             WRITE (IDLOG,*,ERR=2010) 
     &               "   ==> subroutine OSOAA_SURFACE_RAA is called"
             WRITE (IDLOG,*,ERR=2010) " "
	  ENDIF !Fichier Trace  
            
	  CALL OSOAA_SURFACE_CASE("RAA",LUM_NBMU,RMU,CHR,WIND,SEA_IND,
     &	                           OS_NB,OS_NS,OS_NM,
     &	                           FICRAA,TRACE,IER)

          IF (IER.NE.0) GOTO 3000   ! cas d'erreur       

      ENDIF ! Calcul de la matrice RAA
	 



C =====================================================================
C* Cas de la matrice de transmission air --> mer
C =====================================================================
            

C* Constitution du nom du fichier TAW
C  --------------------------------------   
      CALL OSOAA_NOM_FIC_INTERFACE("TAW",NBMU_GAUSS,OS_NB,
     &                              TETAS,ADD_TETAS,TETASW,ADD_TETASW,
     &                              FICANGLES_USER,SEA_IND,WIND,FICS)
     	
      FICTAW = DIRS(1:LDIRS)//'/'//FICS
      LFICS=INDEX(FICTAW,' ')-1
      	 
      IF (TRACE) THEN
	  WRITE (IDLOG,*,ERR=2010) 
     &               "\n\n\n   --> TAW Matrix file : " , 
     &               FICTAW(1:LFICS)
      ENDIF !Fichier Trace  
	 
C* Si le fichier TAW existe d�j�, la routine n'est pas lanc�e
C  ---------------------------------------------------------------     
      INQUIRE(FILE=FICTAW(1:LFICS),EXIST=EX)
	  
      IF( EX) THEN  
 	    
	  IF (TRACE) THEN
	      WRITE (IDLOG,*,ERR=2010) 
     &               "       --> TAW file has already been calculated"
	  ENDIF !Fichier Trace  
	    
      ELSE   
      
C* Calcul du fichier TAW
C  ------------------------- 
          WRITE(6,*) 'Matrix TAW : ', FICTAW(LDIRS+2:LFICS)
          WRITE(6,*)'-- TAW Matrix file is being calculated'   
	  CALL FLUSH(6)	!Force l'envoie du message � l'�cran
	     
	  IF (TRACE) THEN
	     WRITE (IDLOG,*,ERR=2010) 
     &               "--Calculation of TAW Matrix file : " 
             WRITE (IDLOG,*,ERR=2010) 
     &               "   ==> subroutine OSOAA_SURFACE_TAW is called" 
             WRITE (IDLOG,*,ERR=2010) " "
	  ENDIF !Fichier Trace  
            
	  CALL OSOAA_SURFACE_CASE("TAW",LUM_NBMU,RMU,CHR,WIND,SEA_IND,
     &	                           OS_NB,OS_NS,OS_NM,
     &	                           FICTAW,TRACE,IER)
 
          IF (IER.NE.0) GOTO 3100   ! cas d'erreur       

      ENDIF ! Calcul de la matrice TAW
	 




C =====================================================================
C* Cas de la matrice de r�flexion mer --> mer
C =====================================================================
            

C* Constitution du nom du fichier RWW
C  --------------------------------------   
      CALL OSOAA_NOM_FIC_INTERFACE("RWW",NBMU_GAUSS,OS_NB,
     &                              TETAS,ADD_TETAS,TETASW,ADD_TETASW,
     &                              FICANGLES_USER,SEA_IND,WIND,FICS)
     	
      FICRWW = DIRS(1:LDIRS)//'/'//FICS
      LFICS=INDEX(FICRWW,' ')-1
	 
      IF (TRACE) THEN
	  WRITE (IDLOG,*,ERR=2010) 
     &               "\n\n\n   --> RWW Matrix file : " ,
     &               FICRWW(1:LFICS)
      ENDIF !Fichier Trace  
	 
C* Si le fichier RWW existe d�j�, la routine n'est pas lanc�e
C  ---------------------------------------------------------------
      INQUIRE(FILE=FICRWW(1:LFICS),EXIST=EX)
	  
      IF( EX) THEN  
	    
	  IF (TRACE) THEN
	      WRITE (IDLOG,*,ERR=2010) 
     &               "       --> RWW file has already been calculated"
	  ENDIF !Fichier Trace  
	    
      ELSE   
      
C* Calcul du fichier RWW
C  ------------------------- 
          WRITE(6,*) 'Matrix RWW : ', FICRWW(LDIRS+2:LFICS)
          WRITE(6,*)'-- RWW Matrix file is being calculated'   
	  CALL FLUSH(6)	!Force l'envoie du message � l'�cran
	     
	  IF (TRACE) THEN
	     WRITE (IDLOG,*,ERR=2010) 
     &               "--Calculation of RWW Matrix file : " 
             WRITE (IDLOG,*,ERR=2010) 
     &               "   ==> subroutine OSOAA_SURFACE_RWW is called" 
             WRITE (IDLOG,*,ERR=2010) " "
	  ENDIF !Fichier Trace  
            
	  CALL OSOAA_SURFACE_CASE("RWW",LUM_NBMU,RMU,CHR,WIND,SEA_IND,
     &	                           OS_NB,OS_NS,OS_NM,
     &	                           FICRWW,TRACE,IER)
 
          IF (IER.NE.0) GOTO 3200   ! cas d'erreur       

      ENDIF ! Calcul de la matrice RWW
	 



C =====================================================================
C* Cas de la matrice de transmission mer --> air
C =====================================================================
            

C* Constitution du nom du fichier TWA
C  --------------------------------------   
      CALL OSOAA_NOM_FIC_INTERFACE("TWA",NBMU_GAUSS,OS_NB,
     &                              TETAS,ADD_TETAS,TETASW,ADD_TETASW,
     &                              FICANGLES_USER,SEA_IND,WIND,FICS)
     	
      FICTWA = DIRS(1:LDIRS)//'/'//FICS
      LFICS=INDEX(FICTWA,' ')-1
       
      IF (TRACE) THEN
	  WRITE (IDLOG,*,ERR=2010) 
     &               "\n\n\n   --> TWA Matrix file : " ,
     &               FICTWA(1:LFICS)
      ENDIF !Fichier Trace  
	 
C* Si le fichier TWA existe d�j�, la routine n'est pas lanc�e
C  ---------------------------------------------------------------     
      INQUIRE(FILE=FICTWA(1:LFICS),EXIST=EX)
	  
      IF( EX) THEN  
	    
	  IF (TRACE) THEN
	      WRITE (IDLOG,*,ERR=2010) 
     &               "       --> TWA file has already been calculated"
	  ENDIF !Fichier Trace  
	    
      ELSE   
      
C* Calcul du fichier TWA
C  ------------------------- 
          WRITE(6,*) 'Matrix TWA : ', FICTWA(LDIRS+2:LFICS)
	  WRITE(6,*) '-- TWA Matrix file is being calculated'   
	  CALL FLUSH(6)	!Force l'envoie du message � l'�cran
	     
	  IF (TRACE) THEN
	     WRITE (IDLOG,*,ERR=2010) 
     &               "--Calculation of TWA Matrix file : " 
             WRITE (IDLOG,*,ERR=2010) 
     &               "   ==> subroutine OSOAA_SURFACE_TWA is called" 
             WRITE (IDLOG,*,ERR=2010) " "
	  ENDIF !Fichier Trace  
            
	  CALL OSOAA_SURFACE_CASE("TWA",LUM_NBMU,RMU,CHR,WIND,SEA_IND,
     &	                           OS_NB,OS_NS,OS_NM,
     &	                           FICTWA,TRACE,IER)
 
          IF (IER.NE.0) GOTO 3300   ! cas d'erreur       

      ENDIF ! Calcul de la matrice TWA
	 



     
C* Fermeture fichier Trace
C-------------------
      CLOSE(IDLOG)


C* Fin nominale 
C-------------------
      GOTO 9999
            
C* Cas d'erreur et retour du status -1 au programme appelant  
C----------------------------------------------
 1900 WRITE(6,*) '  OSOAA_SURFACE : ERROR_1900 '
      WRITE(6,*) '  => Error on DIRS : maybe too long'
      WRITE(6,*) '                     or incorrect directory name'
      WRITE(6,*) '     (Name of the storage dir. for SURFACE files)'
      WRITE(6,*) '  => Check argument '
      WRITE(6,*) '  => Check if CTE_LENDIR has to be adjusted.' 
      GOTO 9998
      
 2000 WRITE(6,*) '  OSOAA_SURFACE : ERROR_2000 on logfile opening' 
      GOTO 9998  

 2010 WRITE(6,*) '  OSOAA_SURFACE : ERROR_2010 on logfile writing'
      GOTO 9998

 2100 WRITE(6,*) '  OSOAA_SURFACE : ERROR_2100: '
      WRITE(6,*) '  => Error on angles file opening'
      GOTO 9998  

 2101 WRITE(6,*) '  OSOAA_SURFACE : ERROR_2101: '
      WRITE(6,*) '  => Error on angles file reading'
      GOTO 9998  
      
 3000 WRITE(6,*) '  OSOAA_SURFACE : ERROR_3000  '
      WRITE(6,*) '      on subroutine OSOAA_SURFACE_RAA'
      GOTO 9998     

 3100 WRITE(6,*) '  OSOAA_SURFACE : ERROR_3100  '
      WRITE(6,*) '      on subroutine OSOAA_SURFACE_TAW'
      GOTO 9998 
      
 3200 WRITE(6,*) '  OSOAA_SURFACE : ERROR_3200  '
      WRITE(6,*) '      on subroutine OSOAA_SURFACE_RWW'
      GOTO 9998     

 3300 WRITE(6,*) '  OSOAA_SURFACE : ERROR_3300  '
      WRITE(6,*) '      on subroutine OSOAA_SURFACE_TWA'
      GOTO 9998
                                                
9998  IER=-1             
9999  RETURN   

C* Format
C---------   
  222 FORMAT(I4,1X,D21.14,2X,F7.3,2X,D21.14,2X)

      
      
      END      !FIN DE LA PROCEDURE OSOAA_SURFACE
      
      
      
      
      
C==============================================================================
C PROCEDURE: OSOAA_NOM_FIC_INTERFACE
C ==========
C      Cette proc�dure g�n�re le nom du fichier d'interface en fonction de :
C	- l'indice de l'eau : IND
C      	- la vitesse du vent : WIND
C       - le nombre d'angles de Gauss utilis�s NBMU_GAUSS
C       - les angles z�nithal solaire dans l'air TETAS et dans la mer TETASW
C         s'ils ne sont pas des angles de Gauss ou l'angle nul
C       - le nom du fichier d'angles utilisateur FICANGLES_USER
C          (en supprimant son arborescence) 
C
C      On impose d'avoir :
C         IND au format F5.3.
C         WIND au format F4.1, 
C         TETAS et TETASW au format F5.2
C
C      Le nom du fichier d'interface air/mer sera sous la forme
C      (ci-dessous pour le cas du glitter "RAA") :
C
C      RAA-IND-WIND-MUnb-SZAnn.nnn-TSZAnn.nnn-NomFicUser avec 
C      - IND au format F5.3 (ex : 1.500) 
C      - WIND au format F4.1 (ex : 12.5) 
C      - RadMUnb le nombre d'angles de Gauss du champ de luminance (ex : RadMU40)
C      - NBNb l'ordre jusqu'au quel sont calcul�s les termes de la d�composition en 
C        s�ries de Fourier de la matrice 
C        (ex : NB80 pour le cas de 40 angles de Gauss donnant OS_NB = 80)
C      - SZAnn.nnn l'angle z�nithal solaire dans l'air F6.3 (ex : 30.000)
C      - TSZAnn.nnn l'angle z�nithal solaire dans la mer F6.3 (ex : 21.909) 
C      - NomFicUser le nom du fichier utilisateur (sans arborescence) (ex : MyAngles)
C
C      On convertit WIND en une chaine de caract�res CWIND(1:4) 
C      Pour cela on passe du Format F4.1 * 10 => A4
C           Le dernier caract�re CRN(4) est la d�cimale de WIND,
C           etc.
C
C      Selon le type de fichier la base de chaine sera (4 caract�res) :
C			RAA- (pour une r�flexion Air / Air)
C                       TAW- (pour une transmission Air / Mer)
C                       RWW- (pour une r�flexion Mer / Mer)
C                       TWA- (pour une transmission Mer / Air)
C
C
C Description des param�tres entr�e / sortie
C ------------------------------------------
C       CBASE (CHARACTER*3) : (E) Base du nom (RAA, TAW, RWW ou TWA)
C	NBMU_GAUSS (I4)	: (E) Nombre d'angles de Gauss utilis�s
C	OS_NB (I4)	: (E) Ordre maximal � utiliser pour le d�veloppement en
C                             s�ries de Fourier des matrices d'interface.
C       TETAS (double) : (E) Angle z�nithal solaire dans l'air
C       ADD_TETAS (logical) : (E) Indicateur si TETAS doit �tre ajout� au nom
C       TETASW (double) : (E) Angle z�nithal solaire dans la mer
C       ADD_TETASW (logical) : (E) Indicateur si TETASW doit �tre ajout� au nom
C       FICANGLES_USER (CHARACTER*CTE_LENFIC2)	: (E) Nom du fichier des angles 
C                                                 "utilisateurs" (chemin complet)
C	IND (double)	: (E) Indice de l'eau
C	WIND (double)	: (E) Vitesse du vent m/s
C
C	FICS (CHARACTER*CTE_LENFIC1) : (S) nom du fichier d'interface air/mer 
C					  (sans arborescence)
C 
C
C Description des fichiers utilis�s	
C ---------------------------------
C     Aucun : seul le nom du fichier utilisateur est utile (pas son contenu).
C
C Constantes utilis�es:
C --------------------
C    CTE_LENFIC1 : Longueur des noms de fichiers sans arborescence.
C    CTE_LENFIC2 : Longueur des noms de fichiers avec arborescence.
C
C Common utilis�:
C --------------
C     Aucun
C
C Cas d'erreur :
C ------------
C     Aucun
C
C==============================================================================
      SUBROUTINE OSOAA_NOM_FIC_INTERFACE
     &                		( CBASE, NBMU_GAUSS, OS_NB,
     &				  TETAS, ADD_TETAS,TETASW, ADD_TETASW,
     &                  	  FICANGLES_USER,IND, WIND, FICS)

      IMPLICIT NONE

C* D�claration des variables
C  -------------------------         
      DOUBLE PRECISION WIND 	  ! (E) Vitesse du vent m/s
      DOUBLE PRECISION IND	  ! (E) Indice de l'eau.
      DOUBLE PRECISION TETAS      ! (E) Angle z�nithal solaire dans l'air
      DOUBLE PRECISION TETASW     ! (E) Angle z�nithal solaire dans la mer				
      CHARACTER*CTE_LENFIC2 FICANGLES_USER  ! (E) chemin et nom du fichier des angles 
                                            ! "utilisateurs"
      CHARACTER*3 CBASE  ! (E) Base du fichier d'interface (RAA, RWW, TAW ou TWA)
      			 ! Limit�e � 3 caract�res
       
      CHARACTER*CTE_LENFIC1 FICS  ! (S) nom du fichier d'interface
      
          
      CHARACTER*3 CWIND		  ! Chaines de caract�res
      CHARACTER*4 CIND
      CHARACTER*4 CNBMU 
      CHARACTER*4 COSNB
      CHARACTER*6 CTETAS 
      CHARACTER*6 CTETASW    
      
      INTEGER*2 I 
      
      INTEGER*4 IDEB, IDEB_CH, IFIN, IFIN_CH  ! position de d�but et fin d'une chaine 
      					      ! de caract�res   
     
      INTEGER*4 NBMU_GAUSS  ! (E) Nombre d'angles de Gauss utilis�s 
      INTEGER*4 OS_NB	    ! (E) Ordre maximal � utiliser pour le d�veloppement en
                            !     s�ries de Fourier des matrices d'interface.      	 
      LOGICAL ADD_TETAS	    ! =vrai s'il faut ajouter TETAS au nom du fichier
      LOGICAL ADD_TETASW    ! =vrai s'il faut ajouter TETASW au nom du fichier



C*-------------
C* Traitements                        
C*-------------

C --------- initilisation
      DO I=1,CTE_LENFIC1
         FICS(I:I) = ' '
      ENDDO   	    
      
C --------- Conversion en chaines de caract�res des param�tres d'entr�e	
C     Multiplication par 1000.00001 : Evite pb d'arrondi en tronquant,
C     sans modifier le nom attendu du fichier
      WRITE(CIND,'(I4)') int(IND*1000.0001)	
      WRITE(CWIND,'(I3)') int(WIND*10)  
      WRITE(CNBMU,'(I4)') NBMU_GAUSS	
      WRITE(COSNB,'(I4)') OS_NB		
      WRITE(CTETAS,'(I5)') int(TETAS*1000.0001)
      WRITE(CTETASW,'(I5)') int(TETASW*1000.0001)
C --------- Les blancs sont remplac�s par des 0	      
      DO I=1,5
	 IF( CTETAS(I:I).EQ.' ') CTETAS(I:I) = '0'
	 IF( CTETASW(I:I).EQ.' ') CTETASW(I:I) = '0'
      ENDDO   

      DO I=1,4
         IF( CIND(I:I).EQ.' ') CIND(I:I) = '0'
      ENDDO   
      
      DO I=1,3
	 IF( CWIND(I:I).EQ.' ') CWIND(I:I) = '0'
      ENDDO

C -------- Construction de la base de chaine du type de fichier
      FICS(1:3) = CBASE(1:3)	
      FICS(4:4) = '-'
           
C -------- Construction de la chaine de caract�res pour l'indice IND	    
      FICS(5:5) = CIND(1:1)     ! Chiffre des unit�s
      FICS(6:6) = '.'	        ! Virgule
      FICS(7:9) = CIND(2:4)   ! Trois premi�res d�cimales   	    
      FICS(10:11) = '-'

C -------- Construction de la chaine de caract�res pour l'indice WIND	    
      FICS(11:12) = CWIND(1:2)     ! Chiffres des unit�s
      FICS(13:13) = '.'	           ! Virgule
      FICS(14:14) = CWIND(3:3)     ! premi�re d�cimale   
      FICS(15:15) = '-'

C -------- Construction de la chaine de caract�res pour MUgauss
C --------    Structuration pour avoir NBMU_GAUSS � gauche (sans "blancs")	                
      FICS(16:20) = 'RadMU'
      
      IF (NBMU_GAUSS.LT.10) THEN
          FICS(21:21) = CNBMU(4:4)	!RadMUn
      ELSE 
          IF (NBMU_GAUSS.LT.100) THEN
              FICS(21:22) = CNBMU(3:4)  !RadMUnn
	  ELSE 
	     IF (NBMU_GAUSS.LT.1000) THEN
                 FICS(21:23) = CNBMU(2:4) !RadMUnnn
	     ELSE !NBMU_GAUSS < 10000
	     	 FICS(21:24) = CNBMU(1:4) !RadMUnnnn
	     ENDIF !NBMU_GAUSS < 1000
	  ENDIF !NBMU_GAUSS < 100
      ENDIF !NBMU_GAUSS < 10

C -------- Construction de la chaine de caract�res pour OS_NB
C --------    Structuration pour avoir OS_NB � gauche (sans "blancs")	                
      IFIN=INDEX(FICS,' ')  
      FICS(IFIN:IFIN+2) = '-NB'
      IFIN=IFIN+3

      IF (OS_NB.LT.10) THEN
          FICS(IFIN:IFIN) = COSNB(4:4)	!NBn
      ELSE 
          IF (OS_NB.LT.100) THEN
              FICS(IFIN:IFIN+1) = COSNB(3:4)  !NBnn
	  ELSE 
	     IF (OS_NB.LT.1000) THEN
                 FICS(IFIN:IFIN+2) = COSNB(2:4) !NBnnn
	     ELSE !OS_NB < 10000
	     	 FICS(IFIN:IFIN+3) = COSNB(1:4) !NBnnnn
	     ENDIF !OS_NB < 1000
	  ENDIF !OS_NB < 100
      ENDIF !OS_NB < 10
      
      
C -------- Construction de la chaine de caract�res pour TETAS
      IF (ADD_TETAS) THEN
          	
	  IFIN=INDEX(FICS,' ')  
	  FICS(IFIN:IFIN+3) = '-SZA'
	  IFIN=IFIN+4
	  
	  FICS(IFIN:IFIN+1) = CTETAS(1:2)   ! Chiffres des unit�s
	  FICS(IFIN+2:IFIN+2) = '.'	    ! Virgule
          FICS(IFIN+3:IFIN+5) = CTETAS(3:5) ! Trois premi�res d�cimales  

      ENDIF
      
C -------- Construction de la chaine de caract�res pour TETASW
      IF (ADD_TETASW) THEN
          	
	  IFIN=INDEX(FICS,' ')  
	  FICS(IFIN:IFIN+4) = '-TSZA'
	  IFIN=IFIN+5
	  
	  FICS(IFIN:IFIN+1) = CTETASW(1:2)   ! Chiffres des unit�s
	  FICS(IFIN+2:IFIN+2) = '.'	     ! Virgule
          FICS(IFIN+3:IFIN+5) = CTETASW(3:5) ! Trois premi�res d�cimales

      ENDIF
        
C -------- Construction de la chaine de caract�res pour NomFicUser  
      IF (FICANGLES_USER.NE.'NO_USER_ANGLES') THEN
		
C       D�termination de la position du nom de fichier sans son arborescence          
	  IFIN_CH=INDEX(FICANGLES_USER,' ')
          IFIN_CH=IFIN_CH-1
	  IF (IFIN_CH.LE.0) IFIN_CH=CTE_LENDIR
	  
	  IDEB_CH=1
	  	  
10	  IDEB=INDEX(FICANGLES_USER(IDEB_CH:IFIN_CH),'/')
	  IDEB_CH=IDEB_CH+IDEB
          IF (IDEB.NE.0) GOTO 10

C       Ajout du nom de fichier d'angles "utilisateur" au nom du fichier    
          IFIN=INDEX(FICS,' ')  
	  FICS(IFIN:IFIN) = '-'
	  IFIN=IFIN+1
	  FICS(IFIN:IFIN+IFIN_CH-IDEB_CH+1) =
     &         FICANGLES_USER(IDEB_CH:IFIN_CH)
      ENDIF     
	     
      END !OSOAA_NOM_FIC_INTERFACE
 



      
