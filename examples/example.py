import os
import capnp
this_dir = os.path.dirname(__file__)
addressbook = capnp.load(os.path.join(this_dir, 'addressbook.capnp'))

def writeAddressBook(fd):
    message = capnp.MallocMessageBuilder()
    addressBook = message.initRoot(addressbook.AddressBook)
    people = addressBook.initPeople(2)

    alice = people[0]
    alice.id = 123
    alice.name = 'Alice'
    alice.email = 'alice@example.com'
    alicePhones = alice.initPhones(1)
    alicePhones[0].number = "555-1212"
    alicePhones[0].type = 'mobile'
    alice.employment.school = "MIT"

    bob = people[1]
    bob.id = 456
    bob.name = 'Bob'
    bob.email = 'bob@example.com'
    bobPhones = bob.initPhones(2)
    bobPhones[0].number = "555-4567"
    bobPhones[0].type = 'home'
    bobPhones[1].number = "555-7654" 
    bobPhones[1].type = addressbook.Person.PhoneNumber.Type.WORK
    bob.employment.unemployed = None # This is definitely bad, syntax will change at some point

    capnp.writePackedMessageToFd(fd, message)

f = open('example', 'w')
writeAddressBook(f.fileno())

def printAddressBook(fd):
    message = capnp.PackedFdMessageReader(f.fileno())
    addressBook = message.getRoot(addressbook.AddressBook)

    for person in addressBook.people:
        print person.name, ':', person.email
        for phone in person.phones:
            print phone.type, ':', phone.number

        which = person.employment.which()
        print which

        if which == addressbook.Person.Employment.Which.UNEMPLOYED:
            print 'unemployed'
        elif which == addressbook.Person.Employment.Which.EMPLOYER:
            print 'employer:', person.employment.employer
        elif which == addressbook.Person.Employment.Which.SCHOOL:
            print 'student at:', person.employment.school
        elif which == addressbook.Person.Employment.Which.SELF_EMPLOYED:
            print 'unemployed'
        print

f = open('example', 'r')
printAddressBook(f.fileno())
