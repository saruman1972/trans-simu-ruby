base = File.dirname(__FILE__)
com = base+'/src/com'
hsmsim = base+'/src/hsmsim'
orgsim = base+'/src/orgsim'

$:.unshift(base) unless $:.include?(base) || $:.include?(File.expand_path(base))
$:.unshift(com) unless $:.include?(com) || $:.include?(File.expand_path(com))
$:.unshift(hsmsim) unless $:.include?(hsmsim) || $:.include?(File.expand_path(hsmsim))
$:.unshift(orgsim) unless $:.include?(orgsim) || $:.include?(File.expand_path(orgsim))


require 'string'
require 'integer'
require 'charset'
require 'dynamic_class'


