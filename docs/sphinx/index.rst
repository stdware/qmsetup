QMSETUP
=======

CMake Modules and Basic Libraries for C/C++ projects.

The commands below come with a module, and a module has to be asked for before
its commands exist. Either name it as a component:

.. code-block:: cmake

   find_package(qmsetup REQUIRED COMPONENTS Deploy)

or import it once the package is found:

.. code-block:: cmake

   find_package(qmsetup REQUIRED)
   qm_import(Deploy)

``COMPONENTS All`` takes every module there is.

.. toctree::
   :maxdepth: 2

   api

.. toctree::
   :maxdepth: 2
   :caption: Modules

   modules/Deploy
   modules/Doxygen
   modules/Filesystem
   modules/Preprocess
   modules/Protobuf
   modules/Qml
   modules/Translate
