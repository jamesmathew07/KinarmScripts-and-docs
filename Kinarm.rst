.. Here are some macros to ease the writing and the reading :) 

hi

Kinarm end-point
================

:Author: Antoine De Comite, James Mathew, Frederic Crevecoeur (PI) and Philippe Lefevre (PI)
:date: 23rd of July 2019
:Copyright: Antoine De Comite

Objective
---------

The Kinarm end-point robot is a device that allows to investigate human planar movements performed in a virtual reality environment. This device is composed of a horizontal semi-transparent mirror that may prevent direct vision of the arm and the handles during the task, two handles attached at the end of the robotic arms, an eye-tracking camera and a manipulendum, contained in the handles that allows to measure the grip and load forces during movement. 
Here is a picture of the setup
.. Insert here an image of the setup


This setup has to be implement for any new experiment, the aim of this document is to provide a user guide for its implementation. 

User guide for the implementation
---------------------------------

This user guide is divided into several sections. First, the environment will be detailed. Then both the **Stateflow** and **Simulink** implementations will be detailed. Finaly, the implementation of the task into Dexterit-E, the software built-in the robotic device, will be explained.

Description of the environment
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

	The aim of this section is to describe the environment used to implement the Kinarm end-point robot **(add version of the device)**. In order to implement a task on this setup, a Simulink diagram has to be created. Simulink is a graphical programming environment developed by Mathworks to model, analyze, control and simulate dynamical systems. For the Kinarm, this environment is used to control the setup. Even though it is an environment developed by Mathworks, no deep knowledge of Matlab language is required to implement a task. 

	Simulink is a graphical environment composed of boxes and links between them. Each box performs a given operation or action defined by the name of the box (see below for the main simulink functions useful for the Kinarm) and the links between the boxes are used to carry the different signals. The implementation of a task on the Kinarm doesn’t need to use a lot of Simulink functions. Only the ones provided by B-Kin will be used; most of the implementation will be concentrated in one single block: the Stateflow chart. 

	Stateflow is an extension of Simulink that allows to implement finite state machine. By definition, a finite state machine is an automaton for which one define states in which the automaton can be and the transition between those different states are ruled by conditions. For example an automaton with three states is represented in Figure 1. Let’s consider that the automaton is in the state 1, it will stay in this state as long as neither ctd 1→3 nor cdt 1→2 are fulfilled. The Kinarm task has to be implemented as an automaton, each state corresponding to a certain configuration of the setup (position and properties of the different targets, properties of the hand-aligned cursor, properties of perturbation loads and force fields, etc) and the transitions linked to some parameters of the task (hand-aligned cursor position or speed, timing conditions, gaze position, etc).  

		.. figure:: https://image.noelshack.com/fichiers/2019/30/3/1563962659-figureautomaton.png
			:width: 300
			:align: center	

			**Figure 1** - Schematic representation of an automaton or finite state machine.
			The three boxes represent the potential states in which the machine can be. The arrows between these boxes represent the possible transitions between the states. The automaton can go from one state to another one only if the condition cdt A -> B is fulfilled.



	The sequence of actions that occurs during a trial of the task is completely defined in Stateflow, the Simulink environment is used to link the task to the Kinarm device (representation of the targets, activation of the perturbations loads and forces fields,etc). The Stateflow block appears in the Simulink environment and is represented by the block chart (see section about Simulink). The next section explains the implementation of a task in Stateflow.


Implementation of a task in stateflow
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

	As discussed in the preceding section, Stateflow consists in implementing a finite state machine or automaton. To do so, the software proposes several components that may be assembled, they are shown in Figure **stateflowfig**. Here are the description of these different components.

	- **States** : The states correspond to the different states in which the automaton can be. The states may contain instructions relative to the state and it is common to give them a name to ease the debugging. The boxes cannot overlap each other, they will appear in red if their sides cross. A state can be contained inside another one, in this case, all the statements defined in the outer one will be true in the inner one except if the inner state overwrite them. 

	- **Transitions** : The transitions correspond to transitions between the states. They are represented by arrows pointing from the starting state to the final one. The transitions between states are ruled by conditions related to the task (position and speed of the hand-aligned cursor, timing restrictions, etc) and are evaluated as follows. Supposed that the automaton is in a given state, at each time step (defined by the discretization step (**see technical details**)), all the exit conditions will be tested in their execution order. If one of these is true, the system will instantaneously transition to the state corresponding to the true condition. The syntax for conditions on transition (which most of the time are boolean conditions) is the following : [condition==true].

	- **Junctions** : The junctions are points where either different input transitions converge into a single output transition or vice versa. They are represented by circles with arrow entering or exiting their circumferences. As for the boxes, a junction that contains several exiting transitions defines an execution order. This one can be modified by right-clicking on any of the exiting transitions. Junctions can be used to reduce the total amount of transitions in the chart. 

	- **Matlab functions** : Matlab functions can be used to define some parameters that are used in the chart. The Matlab functions are not directly linked to the states by transitions, they are called in the states that use them. The syntax of these functions is the same as classical Matlab functions.

	- **Simulink functions** : As for the Matlab functions, Simulink functions can be used to determine parameters that are used elsewhere in the chart. They do not need to be linked to any other states, they just need to be called in the states that need them. Their implementation is the same as classical Simulink function.

		.. figure:: https://image.noelshack.com/fichiers/2019/31/1/1564384577-image1doc.png
			:width: 500
			:align: center

			**Figure 2** - Screenshot of the different components of a Stateflow chart. The numbers represented on the chart correspond to the ones represented next to the different main items. An example of syntax for the comments, name of the state and statements are given in the state. 

	All these components can be combined to perform complex task (**see example section for more details**). 
	The stateflow states and the conditions on the transitions involve various parameters that can either be scalar constants, complex objects (target, force, etc) or event. These different parameters have to be defined in the model explorer (**add a figure showing the GUI with a legend**). The model explorer is a very useful tool contained into Simulink that allows to search for and modify elements of the Simulink environment, state in the stateflow 	chart and variables in both the Simulink environment and the stateflow chart. An important notice concerning the model explorer is that it segregates the variables defined in stateflow and in Simulink. This means that even though the stateflow chart is contained into the Simulink environment, constants defined in the chart are not accessible into the Simulink environment. Variables in the model explorer of the stateflow chart can be classified in two categories: data and events. Data corresponds to variables that are of one of the following types (**ajouter les types de variables ici**) whereas events corresponds to very specific variables (see examples for more details). Data variables have to be defined as one of the following types: 

	- **Constant** : Constants are variables (most of the time integer or double) that are only defined into the stateflow chart. As said in their name, constants variables do not change through the stateflow chart. They can be defined with an initial value in the model explorer.

	- **Input** : Input variables are variables that are defined in the Simulink environment and that are injected into the stateflow chart. When they are defined in the model explorer, they are automatically associated with a port (which corresponds to an entry that appears on the stateflow chart in the Simulink environment). Concerning their dimension, the more robust implement consists in putting -1 which will automatically takes as dimension the one of the input from the Simulink environment.

	- **Output** : Output variables are variables that will be used in the Simulink environment, they contain for example properties of the targets and of the perturbation loads. As for the input variables, the output variables are defined with a port which also corresponds to an exit point that appears on the stateflow chart in the Simulink environment.

	- **Local** : Local variables are variables that are defined inside the stateflow chart and that the scope does not extend to the Simulink environment. Such as constant variables, local variables can be defined with an initial value. The difference being that the value of the local variables can change through the stateflow chart. 

		.. figure:: https://image.noelshack.com/fichiers/2019/31/1/1564384577-image2doc.png
			:width: 500
			:align: center

			**Figure 3** - Screenshot of the model explorer of the Stateflow chart. On the left side of the picture is represented the different components of the Stateflow chart. On the rights side of the picture the content of the model explorer is shown. You may distinguish the different variables, their name, scope and initial value. The initial value are very important for constants since they will related to the values of the constants in the Simulink and Dexterit-E environement (see example for more details).

	These are the more used variable types in a stateflow chart. The remaining types of variables (that can be found in the scope column of the model explorer) are more complex to handle and not necessary for basic to advanced implementation of tasks. Here are some rules of the thumb for the implementation of a task using stateflow. 

	- Always start with representing on paper what you want to do in detail before diving into the implementation of the task. It will save you some precious hours. 

	.. To complete with more rules... 

Implementation of a task into Simulink
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
	The simulink implementation is the one that will allows to create the file needed by the Dexterit-E software in order to run the task. It is supposed in the following that the reader is familiar with the simulink environment, if not true tutorials and information can be found on the following website: `mathworks <www.mathworks.com>`_. The Simulink script has to contain the following blocks, that can be found only (for almost all of them) in the library of the Kinarm computer:

	- **Chart** : This block is the stateflow environment. When double clicking on it you should end up in the Stateflow environment. The inputs and outputs of this block are the one defined in the model explorer of the stateflow chart. 

	- **GUI control** : This is the block that takes care of much of the communicatino between the Task Program (run on the real-time computer) and the BKIN Dexterit-E GUI (run on windows). It controls the timing of the trials and receives feedback from the stateflow chart in the form of an event *e_End_Trial* that you don't have to interact with. 

	- **DataLogging** : This is the block that logs all the data to be saved by the task program including Kinarm-related data as well as events and analog input data. Data logging only occurs when the *logging_enable* input is set to 1.

	- **Parameter_Table_Defn** : This block defines the different parameters that will be defined in the dlm file (that has to be filled in Dexterit-E). It is important to match these parameters with the ones that are defined in the model explorer of Stateflow in order to avoid any complicated debugging (see example for more information). This block is quite important because it will link the variables defined in Stateflow to their correspondent buddies in Dexterit-E.

	- **Show_Target** : This is the block that creates the VCODES (the vcodes are the codes interpreted by the video processing to represents targets and hand-aligned cursors). The inputs of this block are the row of the raw of the **trouver le bon nom** containing the target and the state of this target. The output is a VCODE.

	- **Show_Target_With_Label** : This block creates a VCODE containing all target information based on the target table and target selection for targets with text. The text will appears next or inside the target depending on the position choosen in the TP table.

	- **Process_Video_CMD** : This is the block that will process the VCODES to translate them into video outputs for the Kinarm virtual reality display.

	- **Hand_Feedback** : This is a block that creates the VCODES for the representation of the hand-aligned feedback. No inputs are required, if you want to tweak it (for example to induce a bias between the position of the hand and the hand-aligned cursor). 

	- **KINARM_HandInTarget** : This is a block that sends information about whether the hand of the subject is in a target or not. The output of this block is a vector whose entries are boolean corresponding to the different targets defined in the task. **Warning** there is an inconstitency here between Matlab in which Simulink is defined and the core of this block which is coded in C. By default, the indexes of the output vector of this blocks started at 0, you have to modify it in the Model Explorer by right clicking on the output variable. 

	- **KINARM_DistanceFromTarget** : This block provides feedback indicating the distance between a targets and one of the hands (the concerning hand has to be selected in the block). The same warning message as for the block HandInTarget holds.

	- **KINARM_Apply_Loads** : This is the block that sends the consign to the robot to apply perturbation load to the handles. The inputs of this block are torques that corresponds to the torques that each motor has to apply. These torques correspond to the output of different blocks detailed here after.

	- **Constant_Loads_EP** : This is a block that computes the torques required to apply a constant load on the handles of the robotic device. The input of this block is the row corresponding to the load in the Task Parameter table (TP table).

	- **Velocity_Load_EP** : This block computes the torques required to apply a velocity-dependent load on the handles of the robotic device. The input of this block is the row corresponding to the load in the TP table **ajouter les infos sur la notation matricielle etc**. 

	- **Perturbation** : This block creates a time-dependent profile that can be used as the scaling input to another load block to create a perturbation.

		.. figure:: https://image.noelshack.com/fichiers/2019/31/1/1564384577-image3doc.png
			:width: 500
			:align: center

			**Figure 4** - Representation of the Simulink environment. The red circle represents the icon of the Simulink functions library. The green circle represent the compile button that has to be pushed to run the model. 


	These blocks are the ones that you will use to control a simple task (by simple task, we mean here that the task doesn't involve any of the extensions of the setup). If you want to use one or more of these extensions, you will have to add a block called **Analog Input** that will automatically detects the analog inputs that are switched on. If you ticks the box *Log analog inputs* in the **DataLogging** block, they will be logged. For more information about the available extensions of the device, please refer to section : Extensions of the device. 

	Once you're done writing your task, you can try to compile it by clicking on the *compile* button or by pushing on CTRL+B. A window should open, if any errors occured during compilation, they will appear in this window. 

Preparation of the task with Dexterit-E
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Let's suppose that your Simulink and Stateflow implementations have compiled without errors (most of the time you can ignore the warnings, but the better is always to briefly look at them), the next and last step is to test your task using the robot. To do so, you have to open the last version of the software (to date, it is BKIN-Dexterit-E 3.6.4), select a subject (for the test, you can select the subject AAA AAA) and then clicking on **to complete + figure**. Before being able to run your task, you have a last thing to settle up. You have to give values to the different parameters used in the Simulink diagram and in the Stateflow chart (see example for complete information). In order to do so, click on the create or edit protocol icon. A window with different panels will open. In the general panel, make sure that the hand feedback beahvior corresponds to what you want. In the target table, you have to make sure that the frame of reference is global coordinate system (which is the easiest to use. Three different tables have to be filled in three different panels (target table, load table and TP table), here below you will find schematic reprentation of them. 


**Load table**
	+---------+---------+---------+---------+---------+
	| Load #  | Param 1 | Param 2 | Param 3 | Param 4 |
	+=========+=========+=========+=========+=========+
	| Load 1  |         |         |         |         | 
	+---------+---------+---------+---------+---------+
	| Load 2  |         |         |         |         | 
	+---------+---------+---------+---------+---------+

**Target table**
	+-----------+---------+---------+---------+---------+
	| Target #  | Param 1 | Param 2 | Param 3 | Param 4 |
	+===========+=========+=========+=========+=========+
	| Target 1  |         |         |         |         | 
	+-----------+---------+---------+---------+---------+
	| Target 2  |         |         |         |         | 
	+-----------+---------+---------+---------+---------+

**TP table**
	+---------+---------+---------+---------+---------+
	|  TP #   | Param 1 | Param 2 | Param 3 | Param 4 |
	+=========+=========+=========+=========+=========+
	|  TP 1   |         |         |         |         |
	+---------+---------+---------+---------+---------+
	|  TP 2   |         |         |         |         |
	+---------+---------+---------+---------+---------+

The structures of these tables are similar. Each row correspond to a different load, target, or trial (TP) and each colomn define a parameter for this particular load, target, or trial. For example, considering the target, the parameters could be the size of the target, its location, its color, its label, etc. The different columns that appear in these tables are defined by the constant name you that were entered in the corresponding table in the block **Parameter Table Defn**. The order of the columns will correspond to the value *Col #* that appears in this same block. 

Once you've filled these tables with the parameters corresponding to your task, you'll have to complete the panel Block table. Each row corresponds to a different kind of block for which you can define the trials protocols you want to run and how many time you want each of them to be run. You can select repetitions and randomization. The block reps parameter has to be set to 1 for each block you want to run. 
The last thing you have to make before being able to run the experiment is to verify that all the boxes corresponding to the analog inputs (in the last panel) are ticked. 

	.. figure:: https://image.noelshack.com/fichiers/2019/31/1/1564384799-image4adoc.png
		:width: 500
		:align: center

		**Figure 5** - This figure represents the Dexterit-E interface in which the task may be run. The upper part of the figure represents the window that appears when you open Dexterit-E. Once the subject is selected, you can click on the button custom task (circled in red in the figure) you will end up in the window shown ni Figure 6.

    .. figure:: https://image.noelshack.com/fichiers/2019/31/1/1564384799-image4bdoc.png
        :width: 500
        :align: center

        **Figure 6** - Representation of the second window of the Dexterit-E GUI. To run an experiment, you have to browse and select the task protocol you want to run (should be the one you implemented). You can edit the different parameters of the task by clicking on the edit button (circled in blue in the figure). To run the task, you just have to click on the run button (circled in green in the figure).

How to run a task with Dexterit-E
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Once you're done programming the task (you've done most of the job don't worry), you just have to calibrate the setup. In order to do so, just click on the *Calibrate* button; a window will open. In this window you'll see two red crosses if the robot is not calibrated. To calibrate the arms, you have to move the toward the back of the environment then place the block on their support and finaly pull the arms toward you until they're blocked. Once they are blocked, push on the small black buttons placed on the two black boxes (**see figure**). This will calibrate the hand-aligned cursor. You also have to calibrate the force sensors. To do so, don't touch the handles and click on the *Reset zero* button and you'll be all done. 

	.. figure:: https://image.noelshack.com/fichiers/2019/31/1/1564385286-imagekinarm.jpg
		:width: 500
		:align: center 

		**Figure 7** - Picture of the robotic arm. On the bottom of the picture, the block used for the calibration is represented on the bottom of the picture as well as the button on which you have to push to calibrate the arm and the hand-aligned cursor. The button is located on the top of the black box. 

For the calibration of the extensions, please refer to the corresponding sections.

You then just have to run the task by clicking on the run button. 

Extensions of the device
------------------------

The aim of this section is to develop the different extensions of the Kinarm end-point robot that can be used.

Electromyography (EMG)
^^^^^^^^^^^^^^^^^^^^^^

The electromyographic setup allows to correlates kinematics of the movements with muscular activities registered in the muscles during the task. This setup is composed of 16 surface electrodes, 1 reference electrodes and 2 hubs for plugging the electrodes. If you work with 8 or less electrodes, you only need the main hub (channels ranging from 1 to 8). On this main hub, you will find the 8 channels in which you can plug the different electrodes placed on the belly of the muscles and a lonely channel in which you have to plug the reference electrode. This reference electrode has to be placed on a location with no muscles nearby or no muscles involved in the movement such as the ankle or the knee. 

In order to add the EMG data collection in the simulink script, you have to select *log analog input* in the **DataLogging** block. You'll have to select the channels you want to record, be carefull that they have to be the same as the ones you plugged the surface electrodes. The reference electrode is logged by default.

	.. figure:: https://image.noelshack.com/fichiers/2019/31/1/1564385286-imageemg.jpg
		:width: 500
		:align: center

		**Figure 8** - Image of the EMG branchements. In this figure, different cables are plugged to the white box. The *ref* cable is plugged to the reference electrode (the white pad in the bottom of the figure) and a surface EMG electrodes is plugged on channel 1. More EMG can be plugged to the others available channels. On the top of the figure, the white box is plugged to the computer using the cable shown in this figure. 

Eye tracking
^^^^^^^^^^^^

Kingrip 
^^^^^^^

Example and usefull scripts
---------------------------

A complete example can be found on the following github `GithubKinarm <https://github.com/decomiteA/KinarmScripts-and-docs>`_ in the file named *Creating task programs for BKIN Dexterit-E*. The other files on this repository contains the matlab codes needed for postprocessing the data outputed by the Kinarm end-point robot. 


 
 
